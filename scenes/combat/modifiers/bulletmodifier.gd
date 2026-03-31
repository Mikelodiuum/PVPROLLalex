extends Resource
class_name BulletModifier

## Resource que define las propiedades de un tipo de bala.
## Crear archivos .tres en el Inspector para cada variante.
## Se asigna al jugador via @export o via el sistema de draft.
## Los campos del grupo "Efectos Especiales" son copiados desde AbilityResource
## por player.gd al construir el _effective_modifier.

@export_group("Identidad")
@export var modifier_name := "Normal"           ## Nombre para la UI del draft
@export_multiline var description := ""         ## Descripción para el draft
@export var icon_color := Color.WHITE           ## Color del icono en el draft

@export_group("Proyectil")
@export var speed: float = 650.0               ## Velocidad de la bala
@export var damage: int = 20                   ## Daño por impacto
@export var pierce: int = 1                    ## Cuántos enemigos puede atravesar
@export var lifetime: float = 3.0             ## Segundos antes de desaparecer
@export var color: Color = Color.WHITE         ## Color de la bala
@export var scale: float = 1.0               ## Tamaño de la bala

@export_group("Disparo")
@export var cooldown: float = 0.5             ## Tiempo entre disparos (s)
@export var bullet_count: int = 1             ## Balas por disparo (>1 = shotgun)
@export var spread_angle: float = 0.0        ## Ángulo de dispersión en grados (shotgun)

@export_group("Efectos Especiales")
## Estos campos NO se editan manualmente en archivos .tres de arma;
## son calculados y escritos por player.gd en refresh_effective_modifier().
@export var double_shot_chance: float = 0.0  ## Probabilidad (0–1) de hacer doble daño por bala
@export var execute_bonus_damage: int = 0    ## Daño extra si objetivo tiene <= execute_threshold HP
@export var execute_threshold: int = 0       ## Umbral HP para activar ejecución
@export var bullets_pierce_walls: bool = false ## Bala atraviesa paredes con -50% daño
@export var damage_on_tick: int = 0          ## Daño de veneno por tick (1 tick/s)
@export var tick_duration: float = 0.0       ## Duración total del veneno (s)
