package game

import "core:log"
import "core:fmt"
import "core:slice"
import "core:strings"
import p "../../UrbanByteFlow" //'p' for platform - could be any platform implementing the required api

TEXT_BUFFER_SIZE :: 1000


Texture :: struct{
    fname:string,
    loaded:bool,
    index:int,
    w:f32,
    h:f32,
}

ControllerInput :: struct{
    leftDown:bool,
    rightDown:bool,
    upDown:bool,
    downDown:bool,
    actionDown:bool,
}

Type :: enum {
    BUTTON,
    THING,
}

Entity :: struct{
    type: Type,
    bbox:Rect,
    tex:Texture,
    isHot:bool,
    action:int,
}

ClickerMode :: enum{
    GCM_DRAW,
    GCM_ERASE,
    GCM_COUNT,
}

Memory :: struct {
    tick            :i32,
    window          :Window,
    paletteContainer:Window,
    canvasContainer :Window,
    clicker         :Clicker,
    controller      :ControllerInput,
    entities        :[10]Entity,
    entities_len    :int,
    textBufLen      :int,
    textBuf         :[TEXT_BUFFER_SIZE + 1]u8,
    scratchBuf      :[1000]u8,
    tokenLen        :int,
    tokens          :[100]Token,
}

Input :: struct {
    mousePos:Vec2,
    mouseButtons:[5]bool,
    controllers:[5]ControllerInput,
}

Window :: distinct Rect

Vec2 :: [2]f32

Rect :: struct{
    using pos:Vec2,
    w:f32,
    h:f32,
}

Clicker :: struct {
    using rect:Rect,
    clicked:bool,
    mode:ClickerMode,
}


@(export)
game_init:: proc(mem: ^Memory)->bool{
    log.info("Init")
    mem.clicker = {
        w = 20,
        h = 20,
        mode = .GCM_DRAW,
    }
    mem.window.w = 1600
    mem.window.h = 1200

    //mem.textBuf[0] = 'i'
    //mem.textBuf[1] = 'f'
    //mem.textBuf[2] = ' '
    //mem.textBuf[3] = 'w'
    //mem.textBuf[4] = 'h'
    //mem.textBuf[5] = 'i'
    //mem.textBuf[6] = 'l'
    //mem.textBuf[7] = 'e'
    //mem.textBuf[8] = 0

    //mem.textBufLen = 9

    //tokenCount := scanTokens(mem.textBuf[:mem.textBufLen], mem.tokens[:])

    //log.infof("Token Count:[%v]\n", tokenCount)

    return true
}


@(export)
game_update:: proc(mem: ^Memory, input:^Input)->bool{

    update_clicker(&mem.clicker, input)

    key := u8(p.getCharPressed())

    for key > 0{
        mem.textBuf[mem.textBufLen] = key
        mem.textBuf[mem.textBufLen + 1] = 0
        mem.textBufLen += 1
        log.debug(key)
        key = u8(p.getCharPressed())
    }

    if p.isBackspaced() {
        mem.textBufLen -= 1
        if mem.textBufLen < 0 { 
            mem.textBufLen = 0
        }
        mem.textBuf[mem.textBufLen] = 0
    }

    tokenCount := scanTokens(mem.textBuf[:mem.textBufLen], mem.tokens[:])
    mem.tokenLen = tokenCount

    //fmt.printf("Token Count:[%v]\n", tokenCount)
    //for t in 0..<tokenCount {
    //    fmt.printf("Token[%v]:[%v][%v] | ", t, mem.tokens[t].name, mem.tokens[t].lexeme)
    //}
    //fmt.printf("\n")


    for e in 0..<mem.entities_len{
        update_entity(&mem.clicker, &mem.entities[e])
    }

    mem.tick += 1
    return true
}

@(export)
game_render :: proc(mem: ^Memory, input:^Input)->bool{
    p.beginDrawing()
    p.fillRect(0, 0, mem.window.w, mem.window.h, BLACK)

    textsrc := mem.textBuf[0:mem.textBufLen]


    sb := strings.builder_from_bytes(mem.scratchBuf[:])
    fmt.sbprintf(&sb, "Text Len: %v, Recorded Len:[%v]", len(textsrc), mem.textBufLen)
    p.drawText(mem.window.x + 100, mem.window.h - 200, 90, strings.to_cstring(&sb))


    text := cstring(&mem.textBuf[0])
    p.fillRect(100, 100, mem.window.w/2 - 100, 400, WHITE)
    p.drawText(100 + 5, 100, 30, text)

    processCount :=0


    for i:=0; i < mem.tokenLen; i+=1 {

        t := mem.tokens[i]
        fmt.printf("Checking token:[%v]\n", t)

        #partial switch t.type {
        case .PROCESS :
            processCount += 1
            if mem.tokenLen > 3{
                if mem.tokens[i + 1].type == .LEFT_PAREN {
                    if mem.tokens[i + 3].type == .RIGHT_PAREN {
                        p.fillRect(mem.window.w/2 + f32(220*processCount), 100, 200, 200, RED)

                        buf := mem.scratchBuf
                        len := mem.tokens[i + 2].lexeme.len
                        src := mem.tokens[i + 2].lexeme.src
                        sometext := rawprt_to_cstring(buf[:], src, len)

                        p.drawTextC(mem.window.w/2 + f32(220*processCount) + 200/2 - 50, 100, 50, sometext, WHITE) 

                    }
                }
            }
            
        }
    }

    for e in 0..<mem.entities_len{
        render_entity(&mem.entities[e])
    }
    render_clicker(&mem.clicker)



    //log.infof("tick: %v", mem.tick)
    p.endDrawing()
    return true
}
rawprt_to_cstring :: proc( buf:[]u8, src:rawptr, len:int) -> cstring{
    j := 0
    for ; j < len; j += 1{
        buf[j] = (^u8)((uintptr)(src) + uintptr(j))^
    }
    buf[j] = 0
    return cstring(&buf[0])
}

update_clicker :: proc(clicker:^Clicker, input:^Input){

    controller := input.controllers[0]
    x := clicker.x
    y := clicker.y

    speed :f32= 4

    if controller.leftDown {
        x -= speed
    }
    if controller.rightDown {
        x += speed
    }
    if controller.upDown {
        y -= speed
    }
    if controller.downDown {
        y += speed
    }
    if controller.actionDown {
        clicker.clicked = true
    }else{
        clicker.clicked = false
    }

    clicker.x = input.mousePos.x
    clicker.y = input.mousePos.y
    clicker.clicked = input.mouseButtons[0]

    //clicker.x = x
    //clicker.y = y
}

render_clicker :: proc(clicker:^Clicker){
    //p.fillRect(clicker.x-5, clicker.y-5, clicker.w, clicker.h, {0xFF, 0xFF, 0xFF, 0xFF})
}

pointInRect :: proc(point:[2]f32, rect:[4]f32) -> bool{
    return point.x > rect.x && point.x < rect.x + rect.z && point.y > rect.y && point.y < rect.y + rect.w
}

render_entity :: proc(b:^Entity){


    if b.isHot{
        p.fillRect(
            b.bbox.pos.x - 3,
            b.bbox.pos.y - 3,
            b.bbox.w*5 + 6,
            b.bbox.h*5 + 6,
            {245, 245, 40, 255},
        )
    }

    if b.tex.loaded{
        p.drawImage(b.tex.index, b.bbox.pos.x, b.bbox.pos.y)
    }else{
        p.fillRect(
            b.bbox.pos.x,
            b.bbox.pos.y,
            b.bbox.w,
            b.bbox.h,
            {200, 90, 20, 255},
        )
    }
}


update_entity :: proc(clicker:^Clicker, b:^Entity){

    x := clicker.x
    y := clicker.y

    if p.pointInRect({x, y}, {b.bbox.x, b.bbox.y, b.bbox.w*5, b.bbox.h*5}){
        b.isHot = true

        if b.type == .BUTTON{
            if clicker.clicked{
                fmt.print(b)
            }
        }

    }else{
        b.isHot = false
    }
}

addEntity :: proc(mem:^Memory, type:Type, texFname:string, bbox:Rect ){
    log.info("Adding Entity")
    e := &mem.entities[mem.entities_len]
    e.type = type
    e.tex.fname = texFname
    e.tex.index, e.tex.w, e.tex.h = p.loadTexture(strings.clone_to_cstring(texFname))
    if e.tex.index == -1{
        log.info("No Texture found, skipping adding texture to Entity")
        e.tex.w = bbox.w
        e.tex.h = bbox.h
        e.tex.loaded = false
    }else{
        e.tex.loaded = true
    }
    e.bbox = bbox
    e.bbox.w = e.tex.w
    e.bbox.h = e.tex.h
    mem.entities_len +=1
    log.info(e)
    log.info("Entity Added in slot[%v]", mem.entities_len)
}

draw_mem :: proc(mem_r:rawptr){
    p.drawText(100, 150, 30, fmt.ctprintf("Size of mem: %v", size_of(int) ))
    mem_r_u8:= slice.bytes_from_ptr(mem_r, 1000)

    // Draw mem heading
    // Draw mem block
    x_min :f32= 200
    x:f32= x_min
    y:f32= 200

    f_size      :f32= 60
    f_height    :f32= 0.8 * f_size
    f_width     :f32= 1.3 * f_size

    for i, index in mem_r_u8{
        if index % 4 == 0{ x += 4 }
        if index % 16 == 0{
            x = x_min
            y += f_height
        }
        if index % 64 == 0{ y += 4 }

        p.drawText(x, y, int(f_size), fmt.ctprintf("%2X",    i ))
        x += f_width
    }

}

