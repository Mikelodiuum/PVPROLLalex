extends Resource
class_name GameConfig

## Resource que centraliza TODA la configuración del juego.
## Editar game_config_default.tres en el Inspector — sin tocar código.
## Para añadir nuevas opciones: añadir @export aquí y el sistema las usará automáticamente.

## Dificultad del bot: controla cuantas armas del pool puede usar.
enum BotDifficulty { FACIL = 0, NORMAL = 1, DIFICIL = 2 }

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

@export_group("Armas y Loadout")
@export var weapons_per_loadout := 3            ## Cuántas armas puede llevar cada jugador
@export var weapon_select_enabled := true        ## Mostrar selector de arma activa entre rondas

@export_group("Habilidades (Draft)")
@export var draft_enabled := true               ## Activar/desactivar el draft entre rondas
@export var draft_options_count := 3            ## Cuántas habilidades se muestran al ganador
@export var draft_on_tie := false               ## Hacer draft también en empates

@export_group("Pickups")
@export var pickups_enabled := true             ## Activar/desactivar pickups en el mapa
@export var pickup_respawn_time := 8.0          ## Tiempo de respawn tras recoger (s)
@export var pickup_initial_delay := 0.0         ## Delay antes del primer spawn (s)
@export var pickup_stagger := 0.15              ## Delay entre spawns escalonados (s)

@export_group("Tiempos de Transición")
@export var round_end_delay := 2.0              ## Delay entre fin de ronda y selector/draft (s)
@export var fight_message_duration := 0.8       ## Duración del mensaje "FIGHT!" (s)

@export_group("Bot (P2)")
@export var bot_p2_enabled    := true             ## Si Player2 es controlado por la IA
## FACIL=2 armas basicas | NORMAL=3 armas | DIFICIL=pool completo
@export var bot_p2_difficulty: BotDifficulty = BotDifficulty.NORMAL
