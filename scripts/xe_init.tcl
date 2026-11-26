debug .
if { [info exist ::env(UTH_EMULATOR)] } {
	 host $::env(UTH_EMULATOR)
 } else {
	 host .
}
