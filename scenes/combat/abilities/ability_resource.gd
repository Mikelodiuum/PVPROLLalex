extends Resource
class_name AbilityResource

## Resource que define una habilidad persistente del jugador.
## Crear archivos .tres en el Inspector para cada variante.
## Las habilidades se acumulan entre rondas, pero se reinician entre partidas.

@export_group("Identidad")
@export var ability_name: String = "Habilidad"           ## Nombre para la UI del draft
@export_multiline var description: String = ""            ## Descripción para el draft
@export var icon_color: Color = Color.WHITE               ## Color del icono en el draft

@export_group("Efectos de Daño")
@export var bonus_damage: int = 0                         ## Daño extra por bala (suma al daño base)
@export var damage_multiplier: float = 1.0               ## Multiplicador de daño (1.0 = sin cambio)

@export_group("Efectos de Movimiento y Disparo")
@export var bonus_speed: float = 0.0                     ## Velocidad de movimiento extra
@export var cooldown_reduction: float = 0.0              ## Reducción del tiempo entre disparos (s)

@export_group("Efectos por Ronda")
@export var shield_per_round: int = 0                    ## Escudo que se aplica al inicio de cada ronda
@export var lifesteal_percent: float = 0.0               ## % del daño infligido que se cura (0.0–1.0)
