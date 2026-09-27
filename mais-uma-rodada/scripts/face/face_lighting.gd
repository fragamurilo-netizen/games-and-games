class_name FaceLighting
extends RefCounted
## Luz de estúdio única para todos os retratos (foto oficial de jogador): uma principal grande e
## macia no alto, à esquerda e um pouco de lado; um rebatedor fraco quase de frente; ambiente
## baixo com oclusão; contraluz opcional bem fraca. A sombra do nariz nunca passa da sombra da
## mandíbula (NOSE_SHADOW_MAX é bem menor que o escurecimento da borda do rosto).
##
## Os vetores são de tela: x para a direita, y para baixo, z saindo da tela em direção à câmera.

## Principal: (-0,35; -0,65; 1) normalizado.
const KEY := Vector3(-0.2816, -0.5229, 0.8045)
## Rebatedor: (0,45; -0,15; 1) normalizado.
const FILL := Vector3(0.4066, -0.1355, 0.9035)
const AMBIENT := 0.2
const KEY_K := 0.8
const FILL_K := 0.08
## "Wrap" da principal: quanto a luz dá a volta na forma (pele espalha luz por dentro).
const WRAP := 0.22
## Opacidade máxima da sombra projetada do nariz (0,05 a 0,16 pedido; fica em 0,11).
const NOSE_SHADOW_MAX := 0.11
## Escurecimento da borda do rosto/mandíbula (a sombra do nariz fica sempre abaixo dele).
const JAW_EDGE_AO := 0.12
const RIM := 0.08


## Uniformes de luz para o shader da pele. `contrast` 1 = padrão do jogo; o laboratório de rostos
## permite variar para comparar (0 = luz chapada, 1,4 = mais dramática).
static func uniforms(contrast: float = 1.0) -> Dictionary:
	return {
		"key_dir": KEY,
		"fill_dir": FILL,
		"light_k": Vector4(AMBIENT, KEY_K, FILL_K, WRAP),
		"light_k2": Vector4(NOSE_SHADOW_MAX, RIM, contrast, JAW_EDGE_AO),
	}


## Direção de onde vem a luz, no plano da tela (para brilhos desenhados à mão: olhos, lábios).
static func screen_dir() -> Vector2:
	return Vector2(KEY.x, KEY.y).normalized()
