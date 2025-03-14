#+feature dynamic-literals
package game

import "core:fmt"

TokenType :: enum{
    // Single Character Tokens
    NIL,
    LEFT_PAREN, 
    RIGHT_PAREN, 
    LEFT_BRACE, 
    RIGHT_BRACE, 
    MINUS, 
    PLUS, 
    COMMA, 
    DOT, 
    SEMICOLON, 
    SLASH, 
    STAR, 

    POINTS_TO, 
    BANG, 
    BANG_EQUAL, 
    EQUAL, 
    EQUAL_EQUAL, 
    GREATER, 
    GREATER_EQUAL, 
    LESS, 
    LESS_EQUAL,

    // Literals
    IDENTIFIER, 
    STRING, 
    NUMBER,

    // Keywords
    PROCESS,

    AND, 
    CLASS, 
    IF, 
    ELSE, 
    FALSE, 
    TRUE, 
    OR, 
    FUN, 
    NULL, 
    FOR, 
    PRINT, 
    RETURN, 
    SUPER, 
    THIS, 
    VAR, 
    WHILE, 
    EOF,
    INVALID,
    COMMENT,
}

token_string_table := [TokenType]string{
    // Single Character Tokens
    .NIL            = "",
    .LEFT_PAREN     = "(",
    .RIGHT_PAREN    = ")",
    .LEFT_BRACE     = "{",
    .RIGHT_BRACE    = "}",
    .MINUS          = "-",
    .PLUS           = "+",
    .COMMA          = ",",
    .DOT            = ".",
    .SEMICOLON      = ";",
    .SLASH          = "/",
    .STAR           = "*",

    // 1 or 2 characther Tokens
    .POINTS_TO      = "->",
    .BANG           = "!",
    .BANG_EQUAL     = "!=",
    .EQUAL          = "=",
    .EQUAL_EQUAL    = "==",
    .GREATER        = ">",
    .GREATER_EQUAL  = ">=",
    .LESS           = "<",
    .LESS_EQUAL     = "<=",

    // Literals
    .IDENTIFIER     = "id",
    .STRING         = "string",
    .NUMBER         = "number",

    // Keywords
    .PROCESS        = "process",

    .AND            = "and",
    .CLASS          = "class",
    .IF             = "if",
    .ELSE           = "else",
    .FALSE          = "false",
    .TRUE           = "true",
    .OR             = "or",
    .FUN            = "fun",
    .NULL           = "null",
    .FOR            = "for",
    .PRINT          = "print",
    .RETURN         = "return",
    .SUPER          = "super",
    .THIS           = "this",
    .VAR            = "var",
    .WHILE          = "while",
    .EOF            = "eof",
    .INVALID        = "INVALID",
    .COMMENT        = "COMMENT",
}

keywords := map[string]TokenType{
    "process"    = .PROCESS,

    "and"        = .AND, 
    "class"      = .CLASS, 
    "if"         = .IF,
    "else"       = .ELSE, 
    "false"      = .FALSE, 
    "true"       = .TRUE, 
    "or"         = .OR, 
    "fun"        = .FUN, 
    "null"       = .NULL, 
    "for"        = .FOR, 
    "print"      = .PRINT, 
    "return"     = .RETURN, 
    "super"      = .SUPER, 
    "this"       = .THIS, 
    "var"        = .VAR, 
    "while"      = .WHILE, 
}
Lexeme :: struct {
    src: rawptr,
    start:int,
    len:int,
}

Token :: struct{
    name : string,
    type : TokenType,
    lexeme : Lexeme,
    line : int,
}

token_to_string :: proc(token : Token)->string{

    output := fmt.tprintf("[%v] [%v] [%v]", token_string_table[token.type], token.type, token.lexeme)
    return output
}
TokenTraverser :: struct {
    count:int,
    start:int,
    current:int,
    line:int,
}

scanTokens :: proc(src:[]u8, tokens:[]Token)->int{
    
    tokenTraverser := TokenTraverser{
        line = 1,
    }

    for !isAtEnd(src, &tokenTraverser){
        tokenTraverser.start = tokenTraverser.current
        scanToken(&tokenTraverser, tokens, src)
    }

    //tokens[tokenTraverser.count] = Token{
    //    type = .EOF,
    //    name = "end of file",
    //    lexeme = transmute([]u8)(token_string_table[.EOF]),
    //    line = tokenTraverser.line,
    //}
    //tokenTraverser.count += 1
    return tokenTraverser.count
}


scanToken :: proc(tokenTraverser:^TokenTraverser, tokens:[]Token, src:[]u8){
    c := advance(src, tokenTraverser)

    type:TokenType

    src_ptr:rawptr
    len:int


    switch c {
    case '(': type = .LEFT_PAREN
    case ')': type = .RIGHT_PAREN
    case '{': type = .LEFT_BRACE
    case '}': type = .RIGHT_BRACE
    case '-': type = match(src, tokenTraverser, '>')? .POINTS_TO : .MINUS
    case '+': type = .PLUS
    case ',': type = .COMMA
    case '.': type = .DOT
    case ';': type = .SEMICOLON
    case '/': 
        if match(src, tokenTraverser, '/'){
            type = .COMMENT
            for peek(src, tokenTraverser) != '\n' && !isAtEnd(src, tokenTraverser){
                advance(src, tokenTraverser)
            }
        }else{
            type = .SLASH
        }
    case '*': type = .STAR
              //case '->': type = .POINTS_TO
    case '!': type = match(src, tokenTraverser, '=')? .BANG_EQUAL : .BANG
    case '=': type = match(src, tokenTraverser, '=')? .EQUAL_EQUAL : .EQUAL
    case '>': type = match(src, tokenTraverser, '=')? .GREATER_EQUAL : .GREATER
    case '<': type = match(src, tokenTraverser, '=')? .LESS_EQUAL : .LESS
    case ' ', '\r', '\t':
    case '\n': tokenTraverser.line += 1
    case '"': captureString(tokenTraverser, src, &type)
    case '0'..='9': captureNumber(tokenTraverser, src, &type)
    case 'A'..='Z', 'a'..='z': captureIdentifier(tokenTraverser, src, &type, &src_ptr, &len)
    case    : type = .INVALID
    }
    if type == .INVALID{
        fmt.printfln("Unexpected character.")
        return
    }

    if type != .NIL{
        addToken(tokenTraverser, tokens, type, src_ptr, len)
    }
}

isAtEnd :: proc(src:[]u8, tokenTraverser:^TokenTraverser)->bool{
    return tokenTraverser.current >= len(src) - 1
}

peek :: proc(src:[]u8, tokenTraverser:^TokenTraverser)->u8{
    if tokenTraverser.current >= len(src){
        return 0
    }
    return src[tokenTraverser.current]
}

peekNext :: proc(src:[]u8, tokenTraverser:^TokenTraverser)->u8{
    if tokenTraverser.current + 1 >= len(src){
        return 0
    }
    return src[tokenTraverser.current + 1]
}


advance :: proc(src:[]u8, tokenTraverser:^TokenTraverser)->u8{
    val:= src[tokenTraverser.current]
    tokenTraverser.current += 1
    return val
}

match :: proc(src:[]u8, tokenTraverser:^TokenTraverser, expected : u8)->bool{
    if isAtEnd(src, tokenTraverser){
        return false
    }
    if src[tokenTraverser.current] != expected {
        return false
    }
    tokenTraverser.current += 1
    return true
}

captureString :: proc(tokenTraverser:^TokenTraverser, src:[]u8, type:^TokenType){
    for peek(src, tokenTraverser) != '"' && !isAtEnd(src, tokenTraverser){
        if peek(src, tokenTraverser) == '\n'{
            tokenTraverser.line += 1
        }
        advance(src, tokenTraverser)
    }

    if isAtEnd(src, tokenTraverser){
        fmt.eprintln("Error unterminated String!")
    }

    advance(src, tokenTraverser)
    type^ = .STRING
}

captureNumber :: proc(tokenTraverser:^TokenTraverser, src:[]u8, type:^TokenType){
    for isDigit(peek(src, tokenTraverser)){
        advance(src, tokenTraverser) 
    }
    if peek(src, tokenTraverser) == '.' && isDigit(peekNext(src, tokenTraverser)){
        advance(src, tokenTraverser)
        for isDigit(peek(src, tokenTraverser)){
            advance(src, tokenTraverser) 
        }
    }
    type^ = .NUMBER
}

captureIdentifier :: proc(tokenTraverser:^TokenTraverser, src:[]u8, type:^TokenType, src_ptr:^rawptr, len:^int){
    for isAlphaNumeric(peek(src, tokenTraverser)){
        advance(src, tokenTraverser) 
    }
    val := src[tokenTraverser.start:tokenTraverser.current]

    src_ptr^ = &src[tokenTraverser.start]
    len^ = tokenTraverser.current - tokenTraverser.start

    type^ = keywords[string(val)]
    if type^ == .NIL {
        type^ = .IDENTIFIER
    }
}

isDigit :: proc(r:u8)->bool{
    return r >= '0' && r <= '9'
}
isAlpha :: proc(r:u8)->bool{
    return 'A' <= r && r <= 'Z' || 'a' <= r && r <= 'z' || r == '_'
}

isAlphaNumeric :: proc(r:u8)->bool{
    return isAlpha(r) || isDigit(r)
}

addToken :: proc(tokenTraverser:^TokenTraverser, tokens:[]Token, type: TokenType, src_ptr:rawptr, len:int){
    tokens[tokenTraverser.count]=Token{
        type = type,
        name = token_string_table[type],
        lexeme = Lexeme{src = src_ptr, len = len},
        line = tokenTraverser.line,
    }
    tokenTraverser.count += 1
}









