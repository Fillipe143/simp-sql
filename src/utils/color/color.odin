package color

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

random :: proc() -> rl.Color {
    l := rand.float32_range(0.5, 0.65)
    c := rand.float32_range(0.1, 0.15)
    s, cv := math.sincos(rand.float32_range(0, math.TAU))
    
    lab := [3]f32{ l, c * cv, c * s }
    lms := [3]f32{
        lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2],
        lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2],
        lab[0] - 0.0894841775 * lab[1] - 1.2914855480 * lab[2],
    }

    f := lms * lms * lms
    lin := [3]f32{
        +4.0767416621 * f[0] - 3.3077115913 * f[1] + 0.2309699292 * f[2],
        -1.2684380046 * f[0] + 2.6097574011 * f[1] - 0.3413193965 * f[2],
        -0.0041960863 * f[0] - 0.7034186147 * f[1] + 1.7076147010 * f[2],
    }

    res: [3]u8
    for i in 0..<3 {
        v := math.clamp(lin[i], 0, 1)
        v = v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1/2.4) - 0.055
        res[i] = u8(v * 255 + 0.5)
    }

    return rl.Color{res[0], res[1], res[2], 255}
}

