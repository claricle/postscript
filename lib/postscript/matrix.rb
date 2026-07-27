# frozen_string_literal: true

module Postscript
  # 2D affine transformation matrix [a b c d e f].
  #
  # Used by both PS-side (CTM, transforms) and SVG-side (transform
  # attribute parsing). General-purpose; lives here so both postsvg
  # and a future pdf gem can share it.
  class Matrix
    attr_accessor :a, :b, :c, :d, :e, :f

    def initialize(a: 1, b: 0, c: 0, d: 1, e: 0, f: 0)
      @a = a
      @b = b
      @c = c
      @d = d
      @e = e
      @f = f
    end

    def multiply(matrix)
      result = Matrix.new
      result.a = (@a * matrix.a) + (@c * matrix.b)
      result.b = (@b * matrix.a) + (@d * matrix.b)
      result.c = (@a * matrix.c) + (@c * matrix.d)
      result.d = (@b * matrix.c) + (@d * matrix.d)
      result.e = (@a * matrix.e) + (@c * matrix.f) + @e
      result.f = (@b * matrix.e) + (@d * matrix.f) + @f
      result
    end

    def translate(tx, ty)
      multiply(Matrix.new(e: tx, f: ty))
    end

    def scale(sx, sy)
      multiply(Matrix.new(a: sx, d: sy))
    end

    def rotate(degrees)
      radians = degrees * Math::PI / 180.0
      m = Matrix.new
      m.a = Math.cos(radians)
      m.b = Math.sin(radians)
      m.c = -Math.sin(radians)
      m.d = Math.cos(radians)
      multiply(m)
    end

    def skew_x(angle)
      radians = angle * Math::PI / 180.0
      multiply(Matrix.new(c: Math.tan(radians)))
    end

    def skew_y(angle)
      radians = angle * Math::PI / 180.0
      multiply(Matrix.new(b: Math.tan(radians)))
    end

    def to_transform_string
      "matrix(#{@a} #{@b} #{@c} #{@d} #{@e} #{@f})"
    end

    def apply_point(x, y)
      {
        x: (x * @a) + (y * @c) + @e,
        y: (x * @b) + (y * @d) + @f,
      }
    end

    def decompose
      scale_x = Math.hypot(@a, @b)
      scale_y = ((@a * @d) - (@b * @c)) / scale_x

      rotation = Math.atan2(@b, @a) * (180.0 / Math::PI)

      skew_x = Math.atan2((@a * @c) + (@b * @d), scale_x * scale_x)
      skew_y = Math.atan2((@a * @b) + (@c * @d), scale_y * scale_y)

      {
        translate: { x: @e, y: @f },
        scale: { x: scale_x, y: scale_y },
        rotate: rotation,
        skew: {
          x: skew_x * (180.0 / Math::PI),
          y: skew_y * (180.0 / Math::PI),
        },
      }
    end

    def invert
      det = (@a * @d) - (@b * @c)
      return Matrix.new if det.abs < 1e-10

      inv = Matrix.new
      inv.a = @d / det
      inv.b = -@b / det
      inv.c = -@c / det
      inv.d = @a / det
      inv.e = ((@c * @f) - (@d * @e)) / det
      inv.f = ((@b * @e) - (@a * @f)) / det
      inv
    end

    def identity?
      @a == 1 && @b.zero? && @c.zero? && @d == 1 && @e.zero? && @f.zero?
    end
  end
end
