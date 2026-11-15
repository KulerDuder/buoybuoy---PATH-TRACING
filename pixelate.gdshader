shader_type canvas_item;

// Control deslizante de 1 (sin pixelar) a 32 (muy pixelado)
uniform int pixel_size : hint_range(1, 32) = 4;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
    // 1. Obtenemos las coordenadas del píxel actual en pantalla
    // 2. Las "cuantizamos" al tamaño de bloque que queramos
    vec2 block_coords = floor(FRAGCOORD.xy / float(pixel_size)) * float(pixel_size);
    
    // 3. Convertimos esas coordenadas de vuelta a UV (0 a 1)
    vec2 uv = block_coords * SCREEN_PIXEL_SIZE;
    
    // 4. Muestreamos la pantalla en ese punto
    COLOR = texture(screen_texture, uv);
}