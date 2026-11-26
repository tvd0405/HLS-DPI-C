#xc on -tbrun
database -open -shm dpi
probe -create . -depth all
run
database -upload
exit
