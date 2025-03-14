echo "Building game"
odin build game -debug -build-mode:dll -out:game_tmp.so -strict-style -vet 

mv game_tmp.so game.so

if pgrep -f platform_game.bin > /dev/null; then
    echo "Platform currently running.... only building game..."
    exit 0
fi

echo "Building Platform"

rm game_*.so
odin build . -debug -define:RAYLIB_SHARED=true -out:platform_game.bin -strict-style -vet 
