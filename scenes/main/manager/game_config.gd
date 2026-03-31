extends Resource
class_name GameConfig

## Resource que centraliza TODA la configuración del juego.
## Crear un archivo .tres en el Inspector para personalizar sin programar.
## Se carga en GameManager como @export.

@export_group("Rondas")
@export var max_rounds := 5                     ## Número máximo de rondas
@export var rounds_to_win := 3                  ## Puntos necesarios para ganar
@export var round_time := 120.0                 ## Duración de cada ronda en segundos

@export_group("Countdown")
@export var countdown_from := 3                 ## Número desde el que empieza el countdown
@export var countdown_step_time := 1.0          ## Duración de cada paso del countdown (s)

@export_group("Jugadores")
@export var default_health := 100               ## Vida por defecto de los jugadores
@export var default_speed := 300.0              ## Velocidad por defecto de movimiento
@export var default_modifier: BulletModifier    ## Modifier por defecto (si no se asigna uno)

@export_group("Draft")
@export var draft_enabled := true               ## Activar/desactivar el draft entre rondas
@export var draft_options_count := 3            ## Cuántas habilidades se muestran
@export var draft_on_tie := false               ## Si hacer draft también en empates
@export var loser_reroll_count: int = 1         ## Rerolls disponibles para el perdedor

@export_group("Pickups")
@export var pickups_enabled := true             ## Activar/desactivar pickups en el mapa
@export var pickup_respawn_time := 8.0          ## Tiempo de respawn tras recoger (s)
@export var pickup_initial_delay := 0.0         ## Delay antes del primer spawn (s)
@export var pickup_stagger := 0.15              ## Delay entre spawns escalonados (s)

@export_group("CPU (Player 2)")
@export var p2_is_cpu: bool = true              ## true = Player2 controlado por IA | false = segundo jugador humano
@export_range(0, 2) var cpu_difficulty: int = 1 ## Dificultad de la IA: 0=Fácil  1=Normal  2=Difícil

@export_group("Tiempos de Transición")
@export var round_end_delay := 2.0              ## Delay entre fin de ronda y draft/siguiente ronda (s)
@export var fight_message_duration := 0.8       ## Duración del mensaje "FIGHT!" (s)
