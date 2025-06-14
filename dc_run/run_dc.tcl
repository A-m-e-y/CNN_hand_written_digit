lappend search_path ../RTL/
set target_library osu05_stdcells.db
set link_library [concat "*" $target_library]
set_wire_load_model -name medium_1K -library osu05_stdcells
current_design MatrixMul_top

analyze -format sverilog {/u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/MatrixMul_top_synth.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/SpecialCaseDetector.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/Rounder.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/R4Booth.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/PreNormalizer.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/Normalizer.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/MSBIncrementer.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/MatrixMulEngine.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/ZeroDetector_Group.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/ZeroDetector_Base.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/WallaceTree.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/spi_slave.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/spi_matrix_sender.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/spi_matrix_loader.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/MAC32_top.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/LeadingOneDetector_Top.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/FullAdder.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/EACAdder.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/DotProductEngine.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/Compressor42.v /u/ameyk/HW_For_AI/CNN_hand_written_digit/RTL/Compressor32.v}

set target_library osu05_stdcells.db
set link_library [concat "*" $target_library]
set_wire_load_model -name medium_1K -library osu05_stdcells
current_design MatrixMul_top


elaborate MatrixMul_top -architecture verilog -library work

current_design MatrixMul_top

set target_library osu05_stdcells.db
set link_library [concat "*" $target_library]
set_wire_load_model -name medium_1K -library osu05_stdcells

link

create_clock clk -period 30 -waveform {0 15}

report_port
check_design
compile -exact_map

report_area
report_cell
report_power
report_timing

write -format Verilog -hierarchy -output MatrixMul_top.netlist
write -format ddc -hierarchy -output MatrixMul_top.ddc

