extends Resource
class_name AbilityResource

## Resource que define una habilidad persistente del jugador.
## Crear archivos .tres en el Inspector para cada variante.
## Las habilidades se acumulan entre rondas, pero se reinician entre partidas.

@export_group("Identidad")
@export var ability_name: String = "Habilidad"            ## Nombre para la UI del draft
@export_multiline var description: String = ""             ## Descripción para el draft
@export var icon_color: Color = Color.WHITE                ## Color del icono en el draft

@export_group("Efectos de Daño")
@export var bonus_damage: int = 0                          ## Daño extra por bala (suma al daño base)
@export var damage_multiplier: float = 1.0                ## Multiplicador de daño (1.0 = sin cambio)
@export var execute_bonus_damage: int = 0                  ## Daño extra si el enemigo tiene ≤ execute_threshold HP
@export var execute_threshold: int = 0                     ## HP máximo del enemigo para activar ejecución
@export var double_shot_chance: float = 0.0               ## Probabilidad de doblar daño por bala (0.0–1.0)

@export_group("Efectos de Movimiento y Disparo")
@export var bonus_speed: float = 0.0                      ## Velocidad de movimiento extra
@export var cooldown_reduction: float = 0.0               ## Reducción del tiempo entre disparos (s)
@export var dash_cooldown_reduction: float = 0.0          ## Reduce el cooldown del dash (s)
@export var bonus_bullet_speed: float = 0.0               ## Velocidad extra de las balas
@export var bonus_bullet_count: int = 0                   ## Balas extra por disparo

@export_group("Efectos de Proyectil")
@export var bonus_pierce: int = 0                         ## Objetivos adicionales que puede atravesar la bala
@export var bullets_pierce_walls: bool = false             ## Las balas atraviesan paredes (con penalización)

@export_group("Efectos de Veneno / DoT")
@export var damage_on_tick: int = 0                       ## Daño por tick de veneno
@export var tick_duration: float = 0.0                    ## Duración total del efecto de veneno (s)

@export_group("Efectos por Ronda")
@export var shield_per_round: int = 0                     ## Escudo que se aplica al inicio de cada ronda
@export var lifesteal_percent: float = 0.0                ## % del daño infligido que se cura (0.0–1.0)
@export var bonus_max_health: int = 0                     ## HP máximos adicionales permanentes por ronda
@export var health_regen_per_second: float = 0.0          ## HP que se recuperan por segundo durante la ronda

@export_group("Efectos Especiales")
@export var hp_drain_per_second: float = 0.0              ## % de HP máximo que se drena por segundo (berserker)
@export var invincible_during_dash: bool = false           ## Eres inmune al daño mientras haces dash
