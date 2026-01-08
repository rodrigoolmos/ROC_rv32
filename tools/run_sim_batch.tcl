# Validar si la variable no está vacía
if {$top_simu == ""} {
    error "No se especificó el nombre del módulo top.!!!!!!!!!!!!!!!!"
} else {
    puts "Simulando el módulo top: $top_simu"
}

# Resolver rutas relativas al script (robusto ante el cwd desde el que se invoque).
set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ".."]]

set sim_dir [file join $root_dir questasim]
file mkdir $sim_dir

# Crear/lib map de work dentro de questasim/
set work_lib [file join $sim_dir work]
vlib $work_lib
vmap work $work_lib

# Compilar desde el root del repo (paths del flist relativos al root)
cd $root_dir

# Compilar usando file list
set flist [file join $root_dir tb_ROC_RV32.flist]
if {![file exists $flist]} {
    error "No se encontró tb_ROC_RV32.flist en: $flist"
}
vlog -sv -work work -f $flist

# Carga el testbench o módulo principal en QuestaSim, habilitando el rastreo de aserciones.
vsim -assertdebug -voptargs=+acc work.$top_simu

# Ejecuta la simulación hasta que el testbench termine ($finish/$fatal)
run -all

quit -f