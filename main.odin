package hotreload

import "core:log"
import rl "vendor:raylib"
import "core:dynlib"
import "core:os"
import "core:os/os2"
import "core:mem"
import "core:fmt"

GameCode :: struct {
    init : proc(rawptr)->bool,
    update : proc(rawptr, rawptr)->bool,
    render : proc(rawptr, rawptr)->bool,
    lib : dynlib.Library,
    time : os.File_Time,
    version: int, 
}

game_controller_input :: struct{
    leftDown:bool,
    rightDown:bool,
    upDown:bool,
    downDown:bool,
    actionDown:bool,
}


GameInput :: struct{
    mousePos:rl.Vector2,
    mouseButtons:[5]bool,
    controllers:[5]game_controller_input,
}

PlatformState :: struct{
    mem_size:u32,
    mem:rawptr,
    inputRecHandle:int,
    images:[20]rl.Texture2D,
    images_len:int,
}


platform_state: PlatformState


test :: proc(){
    log.info("This is a test")
}

beginDrawing :: proc(){

}
endDrawing :: proc(){
}

drawText :: proc(x:int, y:int, size:int, text:cstring){
    rl.DrawText(text, i32(x), i32(y), i32(size), rl.GRAY)
}

fillRect :: proc(x:f32, y:f32, w:f32, h:f32, col:[4]u8){
    rl.DrawRectanglePro(rl.Rectangle{x, y, w, h}, rl.Vector2{0, 0}, 0, rl.Color(col))
}
drawLine :: proc(x1:f32, y1:f32, x2:f32, y2:f32, col:[4]u8){
    rl.DrawLine(i32(x1), i32(y1), i32(x2), i32(y2), rl.Color(col))
}

getMousePos :: proc() -> [2]f32{
    return rl.GetMousePosition()
}
getMouseClicked :: proc()-> bool{
    return rl.IsMouseButtonDown(rl.MouseButton.LEFT)
}

loadTexture :: proc(fname:cstring)->(int, f32, f32){
    if len(fname) == 0 {
        log.warnf("FAILED::EMPTY fname:[%v]", fname)
        return -1, 0, 0
    }
    index := platform_state.images_len
    image := rl.LoadTexture(fname)
    if image.width == 0{
        log.errorf("FAILED::%v", fname)
        return -1, 0, 0
    }
    platform_state.images[index] = image
    platform_state.images_len += 1
    return index, f32(image.width), f32(image.height)
}

drawImage :: proc(index:int, x:f32, y:f32){
    rl.DrawTextureEx(platform_state.images[index], {f32(x), f32(y)}, 0, 5, rl.WHITE)

}

pointInRect :: proc(pos:[2]f32, rect:[4]f32)->bool{
    return rl.CheckCollisionPointRec(pos, transmute(rl.Rectangle) rect)
}




ASPECT_W :: 16
ASPECT_H :: 12
ASPECT_SCALE :: 100
WINDOW_NAME :: "UrbanByte Image"
TARGET_FPS :: 30

initializeWindow :: proc(){
    rl.SetConfigFlags({ .VSYNC_HINT, .WINDOW_TRANSPARENT, .WINDOW_TOPMOST })
    rl.InitWindow(ASPECT_W*ASPECT_SCALE, ASPECT_H*ASPECT_SCALE, WINDOW_NAME)
    rl.SetTargetFPS(TARGET_FPS)

    monitor_handle := rl.GetCurrentMonitor()
    mon_w := rl.GetMonitorWidth(monitor_handle)
    mon_h := rl.GetMonitorHeight(monitor_handle)
    rl.SetWindowPosition(mon_w - rl.GetScreenWidth() - 200, mon_h - rl.GetScreenHeight() - 200)
}

shutdownWindow :: proc(){
    for i := 0; i < platform_state.images_len; i+=1 {
        image := platform_state.images[i]
        fmt.printfln("Unloading Image: %v", image)
        rl.UnloadTexture(platform_state.images[i])
    }
    rl.CloseWindow()
}

game_api_version :=0
game : GameCode
hotreload :: proc(){
    reload := false

    game_dll_mod, game_dll_mod_err := os.last_write_time_by_name(GAME_DLL_PATH)
    if game_dll_mod_err == os.ERROR_NONE && game.time != game_dll_mod {
        reload = true
    }

    if reload {
        game, _ = load_game_api(game_api_version)
        game_api_version += 1
    }
}

processWindowEvents :: proc(){
    if !rl.IsWindowFocused(){
        rl.SetWindowOpacity(0.8)
    }else{
        rl.SetWindowOpacity(1.0)
    }
}




main :: proc(){
    context.logger = log.create_console_logger()
    // ======= Tracking Allocation from odin Overview
    track : mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    // END ======= Tracking Allocation from odin Overview


    initializeWindow()
    defer shutdownWindow()





    game_mem, _ := mem.alloc(mem.Kilobyte*1, mem.DEFAULT_ALIGNMENT)
    

    if game_mem == nil{
        log.error("Failed to allocate memory")
    }else{
        log.info("Successfully Allocated memory")
    }

    platform_state.mem_size = mem.Kilobyte*1
    platform_state.mem = game_mem
    
    
    game, _ = load_game_api(game_api_version)
    log.info(game)
	game_api_version += 1

    game.init(game_mem)


    input:[2]GameInput

    new_input:=&input[0]
    old_input:=&input[1]



    for !rl.WindowShouldClose(){

        hotreload()

        processWindowEvents()

        newController := GetController(new_input, 0)
        oldController := GetController(old_input, 0)

        mem.copy(oldController, newController, size_of(newController))

        processPendingInputs(&platform_state, newController)

        
        new_input.mousePos = rl.GetMousePosition()
        new_input.mouseButtons[0] = rl.IsMouseButtonDown(rl.MouseButton.LEFT)
        
        game.update(game_mem, new_input)

        rl.BeginDrawing()
        rl.ClearBackground(rl.MAGENTA)

        game.render(game_mem, new_input)

        rl.EndDrawing()
        free_all(context.temp_allocator)
    }
    free_all(context.temp_allocator)
    mem.free(game_mem)


    fmt.println("Auditing context")
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

processPendingInputs :: proc(state:^PlatformState, controller:^game_controller_input){
    controller.upDown       = rl.IsKeyDown(.W)
    controller.leftDown     = rl.IsKeyDown(.A)
    controller.downDown     = rl.IsKeyDown(.S)
    controller.rightDown    = rl.IsKeyDown(.D)
}




GetController :: proc(input:^GameInput, index:u8) -> ^game_controller_input{
    return &input.controllers[index]
}



GAME_DLL_DIR :: "game/"
GAME_DLL_PATH :: "game.so"

copy_dll :: proc(to: string) -> bool {
	copy_err := os2.copy_file(to, GAME_DLL_PATH)

	if copy_err != nil {
		fmt.printfln("Failed to copy " + GAME_DLL_PATH + " to {0}: %v", to, copy_err)
		return false
	}

	return true
}

load_game_api :: proc(api_version: int) -> (game: GameCode, ok: bool) {
    log.info("Reloading GameCode")
	mod_time, mod_time_error := os.last_write_time_by_name(GAME_DLL_PATH)
	if mod_time_error != os.ERROR_NONE {
		fmt.printfln(
			"Failed getting last write time of " + GAME_DLL_PATH + ", error code: {1}",
			mod_time_error,
		)
		return
	}

	game_dll_name := fmt.tprintf(GAME_DLL_DIR + "game_%v.so", api_version)
	copy_dll(game_dll_name) or_return

	_, ok = dynlib.initialize_symbols(&game, game_dll_name, "game_", "lib")
	if !ok {
		fmt.printfln("Failed initializing symbols: %v", dynlib.last_error())
        game.update = proc(rawptr, rawptr)->bool{
            return true
        }
        game.render = proc(rawptr, rawptr)->bool{
            return true
        }
	}

	game.version = api_version
	game.time = mod_time
	ok = true

	return
}
