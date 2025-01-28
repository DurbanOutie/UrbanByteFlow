package main

import rl   "vendor:raylib"

main::proc(){
    rl.InitWindow(800, 600, "UrbanByte Flow")
    rl.SetWindowState(rl.ConfigFlags{.WINDOW_RESIZABLE})
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose(){
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        rl.EndDrawing()
    }
}
