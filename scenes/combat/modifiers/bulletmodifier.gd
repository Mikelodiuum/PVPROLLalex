extends Resource
class_name BulletModifier

## Resource que define las propiedades de un tipo de bala.
## Crear archivos .tres en el Inspector para cada variante.
## Se asigna al jugador via @export o via el sistema de draft.

@export_group("Identidad")
@export var modifier_name := "Normal"           ## Nombre para la UI del draft
@export_multiline var description := ""         ## Descripción para el draft
@export var icon_color := Color.WHITE           ## Color del icono en el draft

@export_group("Proyectil")
@export var speed: float = 650.0                ## Velocidad de la bala
@export var damage: int = 20                    ## Daño por impacto
@export var pierce: int = 1                     ## Cuántos enemigos puede atravesar
@export var lifetime: float = 3.0               ## Segundos antes de desaparecer
@export var color: Color = Color.WHITE          ## Color de la bala
@export var scale: float = 1.0                  ## Tamaño de la bala

@export_group("Disparo")
@export var cooldown: float = 0.5               ## Tiempo entre disparos (s)
@export var bullet_count: int = 1               ## Balas por disparo (>1 = shotgun)
@export var spread_angle: float = 0.0           ## Ángulo de dispersión en grados (shotgun)
