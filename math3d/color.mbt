// three.js Color 迁移:线性分量 0..1;十六进制解析支持 #RGB/#RRGGBB。

///| RGB 颜色(各分量 0..1)
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
} derive(Debug)

pub extend Color with Debug::{to_repr}

///| 构造
pub fn Color::new(r : Double, g : Double, b : Double) -> Color {
  { r, g, b }
}

///| 白色
pub fn Color::white() -> Color {
  { r: 1.0, g: 1.0, b: 1.0 }
}

///| 黑色
pub fn Color::black() -> Color {
  { r: 0.0, g: 0.0, b: 0.0 }
}

///| 红绿蓝便捷色
pub fn Color::red() -> Color {
  { r: 1.0, g: 0.0, b: 0.0 }
}

pub fn Color::green() -> Color {
  { r: 0.0, g: 1.0, b: 0.0 }
}

pub fn Color::blue() -> Color {
  { r: 0.0, g: 0.0, b: 1.0 }
}

///| 解析 #RGB / #RRGGBB(无 # 亦可),非法返回 None
pub fn Color::from_hex(s : String) -> Color? {
  let h = if s.length() > 0 && s[0] == '#' {
    s[1:]
  } else {
    s
  }
  fn hex_val(c : Int) -> Int? {
    if c >= 48 && c <= 57 {
      Some(c - 48)
    } else if c >= 97 && c <= 102 {
      Some(c - 87)
    } else if c >= 65 && c <= 70 {
      Some(c - 55)
    } else {
      None
    }
  }
  match h.length() {
    3 => {
      let r = hex_val(h[0].to_int())
      let g = hex_val(h[1].to_int())
      let b = hex_val(h[2].to_int())
      match (r, g, b) {
        (Some(r), Some(g), Some(b)) =>
          Some({
            r: (r * 17).to_double() / 255.0,
            g: (g * 17).to_double() / 255.0,
            b: (b * 17).to_double() / 255.0,
          })
        _ => None
      }
    }
    6 => {
      let r1 = hex_val(h[0].to_int())
      let r2 = hex_val(h[1].to_int())
      let g1 = hex_val(h[2].to_int())
      let g2 = hex_val(h[3].to_int())
      let b1 = hex_val(h[4].to_int())
      let b2 = hex_val(h[5].to_int())
      match (r1, r2, g1, g2, b1, b2) {
        (Some(r1), Some(r2), Some(g1), Some(g2), Some(b1), Some(b2)) =>
          Some({
            r: (r1 * 16 + r2).to_double() / 255.0,
            g: (g1 * 16 + g2).to_double() / 255.0,
            b: (b1 * 16 + b2).to_double() / 255.0,
          })
        _ => None
      }
    }
    _ => None
  }
}

///| 输出 #RRGGBB(分量钳到 0..1)
pub fn Color::to_hex(self : Color) -> String {
  fn byte(v : Double) -> Int {
    let c = if v < 0.0 {
      0.0
    } else if v > 1.0 {
      1.0
    } else {
      v
    }
    (c * 255.0 + 0.5).to_int()
  }
  let r = byte(self.r)
  let g = byte(self.g)
  let b = byte(self.b)
  let hex = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d",
    "e", "f",
  ]
  "#" + hex[r / 16] + hex[r % 16] + hex[g / 16] + hex[g % 16] +
  hex[b / 16] + hex[b % 16]
}

///| 分量逐项相加(光照累计用)
pub fn Color::add(self : Color, other : Color) -> Color {
  { r: self.r + other.r, g: self.g + other.g, b: self.b + other.b }
}

///| 分量逐项相乘(颜色混合)
pub fn Color::multiply(self : Color, other : Color) -> Color {
  { r: self.r * other.r, g: self.g * other.g, b: self.b * other.b }
}

///| 数乘
pub fn Color::multiply_scalar(self : Color, s : Double) -> Color {
  { r: self.r * s, g: self.g * s, b: self.b * s }
}

///| 线性插值
pub fn Color::lerp(self : Color, other : Color, alpha : Double) -> Color {
  {
    r: self.r + (other.r - self.r) * alpha,
    g: self.g + (other.g - self.g) * alpha,
    b: self.b + (other.b - self.b) * alpha,
  }
}

///| 分量钳到 0..1
pub fn Color::clamp(self : Color) -> Color {
  fn c(v : Double) -> Double {
    if v < 0.0 {
      0.0
    } else if v > 1.0 {
      1.0
    } else {
      v
    }
  }
  { r: c(self.r), g: c(self.g), b: c(self.b) }
}

///| 相等(精确)
pub fn Color::equals(self : Color, other : Color) -> Bool {
  self.r == other.r && self.g == other.g && self.b == other.b
}
