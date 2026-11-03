extends Node
## Cross-run reward selection. Stage reload resets actors, timers, and attacks.
var selected_buff := -1
var last_buff_label := ""
var carried_health := -1.0
var cleared_rooms := 0
