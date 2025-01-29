package main

import "core:strings"
import "core:unicode/utf8"
import "core:fmt"
import "core:mem"

import rl "vendor:raylib"

input_buf : [1<<8]rune
input_buf_len : int

main :: proc(){

    // ======= Tracking Allocation from odin Overview
    track : mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer{
        if len(track.allocation_map) > 0{
            fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map{
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        if len(track.bad_free_array) > 0{
            fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
            for entry in track.bad_free_array{
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }
    // END ======= Tracking Allocation from odin Overview


    rl.InitWindow(800, 600, "UrbanByte Flow")
    defer rl.CloseWindow()
    rl.SetWindowState(rl.ConfigFlags{.WINDOW_RESIZABLE})
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose(){

        c := rl.GetCharPressed()
        if c >= 32 && c <= 127 {
            input_buf[input_buf_len] = c
            input_buf_len +=1
        }
        text := utf8.runes_to_string(input_buf[0:input_buf_len], context.allocator)

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.DrawRectangle(5, 5, rl.GetScreenWidth()-10, rl.GetScreenHeight()-10, rl.LIGHTGRAY)
        rl.DrawText(strings.clone_to_cstring(text), 10, 10, 20, rl.GRAY)

        rl.EndDrawing()
    }
}
