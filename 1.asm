%define NULL 0

%define L_SIZE 16
%define OFFSET_L_FIRST 0
%define OFFSET_L_LAST 8

%define L_E_SIZE 24
%define OFFSET_L_E_DATA 0
%define OFFSET_L_E_NEXT 8
%define OFFSET_L_E_PREV 16

%define T_SIZE 8
%define OFFSET_T_FIRST 0

%define T_E_SIZE 32
%define OFFSET_T_E_DATA 0
%define OFFSET_T_E_LEFT 8
%define OFFSET_T_E_CENTER 16
%define OFFSET_T_E_RIGHT 24

%define TABLE_SIZE 16
%define OFFSET_TAB_L_ARRAY 0
%define OFFSET_TAB_SIZE 8

section .rodata
    stringFormat: DB '%s', 0
    stringVacio: DB 'NULL', 0
    pointerFormat: DB '%p', 0
    bracketListIni: DB '[', 0
    bracketListFin: DB ']', 0
    comma: DB ',', 0

section .text

extern malloc
extern free
extern fprintf

global strLen
global strClone
global strCmp
global strConcat
global strDelete
global strPrint
global listNew
global listAddFirst
global listAddLast
global listAdd
global listRemove
global listRemoveFirst
global listRemoveLast
global listDelete
global listPrint
global n3treeNew
global n3treeAdd
global n3treeRemoveEq
global n3treeDelete
global nTableNew
global nTableAdd
global nTableRemoveSlot
global nTableDeleteSlot
global nTableDelete

;;;;;;;;;;;;;;;;;;;;;;
;;      STRING      ;;
;;;;;;;;;;;;;;;;;;;;;;

strLen:
    xor RCX, RCX; limpia contador
.loop:
    cmp BYTE[RDI + RCX], NULL; caracter fin de linea
    je .fin
    inc RCX
    jmp .loop
.fin:
    mov RAX, RCX;
    ret

strClone:
    PUSH RBX; alineo 16
    ; en RDI ya tengo el string src, asì que se lo paso directamente a strLen
    PUSH RDI;
    SUB RSP, 8
    call strLen 
    ADD RSP, 8
    POP RDI;

    xor RBX, RBX; limpia reg para guardar tamaño string
    mov RBX, RAX; guardo el tamaño string obtenido

    push RDI; guardo RDI
    sub RSP, 8; y alineo a 16
    lea RDI, [RAX + 1]; tamaño de mem a pedir
    call malloc; ahora RAX es un puntero a la memoria pedida.
    add RSP, 8
    pop RDI

    xor RCX, RCX; limpia contador
    xor R11, R11; limpia temporal para copiar caracteres
.loop:
    cmp RCX, RBX
    je .fin
    mov R11B, [RDI + RCX]
    mov [RAX + RCX], R11B; 
    INC RCX
    jmp .loop
.fin:
    mov BYTE[RAX + RCX], NULL; ultimo caracter NULL
    pop RBX;
    ret

strCmp:
    XOR RCX, RCX; limpio contador
    XOR RAX, RAX; limpio retorno
    XOR R11, R11; buffer caracter.
.cmpChar:
    MOV R11b, [RDI + RCX];
    CMP R11b, [RSI + RCX];
    JL .masChico
    JG .masGrande
    JMP .sonIguales
.masChico:
    MOV RAX, 1; es mas chico
    JMP .fin
.masGrande:
    MOV RAX, -1; es mas grande
    JMP .fin
.sonIguales:
    CMP BYTE[RDI + RCX], NULL
    JE .nullChar
    CMP BYTE[RSI + RCX], NULL
    JE .nullChar
    ; aun no terminan strings
    INC RCX
    JMP .cmpChar
.nullChar:
    MOV RAX, 0; iguales
.fin:
    ret

strConcat:
    PUSH RBX
    PUSH R12
    PUSH R13
    PUSH R14
    PUSH R15

    ; consigo los tamaños
    PUSH RDI
    PUSH RSI
    call strLen; la llamo con RDI primero
    XOR R12, R12
    MOV R12, RAX
    MOV RDI, RSI
    call strLen; y ahora con RSI
    XOR R13, R13
    MOV R13, RAX
    POP RSI
    POP RDI

    ; tamaño total con null y malloc
    MOV RBX, R12
    ADD RBX, R13
    INC RBX; 1 mas por el null  

    PUSH RDI
    PUSH RSI
    MOV RDI, RBX
    call malloc
    POP RSI
    POP RDI

    MOV R14, RAX; el puntero al concatenado
    
    ; empiezo a copiar el primero
    XOR R15, R15; buffer caracter
    XOR RCX, RCX; contador
    XOR RDX, RDX; contador para el segundo. Distinto porque el otro sigue recorriendo el concat
.loop1:
    MOV R15b, [RDI + RCX]
    CMP R15b, NULL
    JE .loop2
    MOV [R14 + RCX], R15b
    INC RCX
    JMP .loop1

.loop2:
    MOV R15b, [RSI + RDX]
    CMP R15b, NULL
    JE .finLoop
    MOV [R14 + RCX], R15b
    INC RCX
    INC RDX
    JMP .loop2

.finLoop:
    MOV BYTE[R14 + RCX], NULL
    
    ; y ahora resta hacer frees...

    PUSH RSI
    PUSH RDI
    MOV RDI, RSI
    call free; free RSI
    POP RDI
    POP RSI
    CMP RSI, RDI
    JE .esAlias
    call free; free RDI
.esAlias:

    mov RAX, R14 ; seteo el retorno

    POP R15
    POP R14
    POP R13
    POP R12
    POP RBX
    ret

strDelete:
    jmp free

 
strPrint: ; strPrint(char* a, FILE *pFile)
    MOV RDX, RDI
    MOV RDI, RSI
    MOV RSI, stringFormat
    MOV R10b, [RDX]; voy a ver si es solo un NULL, string vacio
    CMP R10b, 0
    JNE .strNotNull
    MOV RDX, stringVacio
.strNotNull:
    JMP fprintf;        fprintf ( FILE * stream, const char * format, ... );

;;;;;;;;;;;;;;;;;;;;;;
;;      LIST        ;;
;;;;;;;;;;;;;;;;;;;;;;


listNew:
    MOV RDI, L_SIZE
    SUB RSP, 8; alineacion
    call malloc
    ADD RSP, 8
    MOV QWORD[RAX + OFFSET_L_FIRST], NULL
    MOV QWORD[RAX + OFFSET_L_LAST], NULL
    ret

listAddFirst:
    ; pido mem para el nodo
    PUSH RSI; guardo
    PUSH RDI; guardo
    SUB RSP, 8; alineo
    MOV RDI, L_E_SIZE
    call malloc
    ADD RSP, 8
    POP RDI
    POP RSI

    ; ahora RAX es puntero al nuevo nodo.
    MOV R9, [RDI + OFFSET_L_FIRST]; puntero a actual first
    CMP R9, NULL; veo si first de la lista es null
    JNE .notNull
    ; caso null
    MOV [RDI + OFFSET_L_FIRST], RAX
    MOV [RDI + OFFSET_L_LAST], RAX
    MOV [RAX + OFFSET_L_E_DATA], RSI
    MOV QWORD[RAX + OFFSET_L_E_NEXT], NULL
    MOV QWORD[RAX + OFFSET_L_E_PREV], NULL
    ret

.notNull:
    MOV [R9 + OFFSET_L_E_PREV], RAX
    MOV [RAX + OFFSET_L_E_DATA], RSI
    MOV [RAX + OFFSET_L_E_NEXT], R9
    MOV QWORD[RAX + OFFSET_L_E_PREV], NULL
    MOV [RDI + OFFSET_L_FIRST], RAX
    ret

listAddLast:
    ; pido mem para el nodo
    PUSH RSI; guardo
    PUSH RDI; guardo
    SUB RSP, 8; alineo
    MOV RDI, L_E_SIZE
    call malloc
    ADD RSP, 8
    POP RDI
    POP RSI

    ; ahora RAX es puntero al nuevo nodo.
    MOV R9, [RDI + OFFSET_L_LAST]; puntero a actual last
    CMP R9, NULL; veo si last de la lista es null
    JNE .notNull
    ; caso null
    MOV [RDI + OFFSET_L_FIRST], RAX
    MOV [RDI + OFFSET_L_LAST], RAX
    MOV [RAX + OFFSET_L_E_DATA], RSI
    MOV QWORD[RAX + OFFSET_L_E_NEXT], NULL
    MOV QWORD[RAX + OFFSET_L_E_PREV], NULL
    ret

.notNull:
    MOV [R9 + OFFSET_L_E_NEXT], RAX
    MOV [RAX + OFFSET_L_E_DATA], RSI
    MOV [RAX + OFFSET_L_E_PREV], R9
    MOV QWORD[RAX + OFFSET_L_E_NEXT], NULL
    MOV [RDI + OFFSET_L_LAST], RAX
    ret


listAdd: ; void listAdd(list_t* l, void* data, funcCmp_t* fc)
    PUSH RBX; guardo l
    PUSH R12; guardo data
    PUSH R13; guardo fc
    PUSH R14; nodo actual
    PUSH R15; data del nodo actual

    MOV RBX, RDI
    MOV R12, RSI
    MOV R13, RDX
    MOV R14, [RDI + OFFSET_L_FIRST]; pos mem primer nodo

.loop:
    CMP R14, NULL
    JE .nodoNull
    JMP .nodoNotNull

.nodoNull: ; fin de la lista/lista null -> inserta al final de esta
    MOV RDI, RBX
    MOV RSI, R12
    CALL listAddLast
    JMP .fin

.nodoNotNull:
    MOV R15, [R14 + OFFSET_L_E_DATA] ; obtengo data del nodo actual
    ; comparar datos

    MOV RDI, R15
    MOV RSI, R12
    CALL RDX; call funcCmp(nodo->data, data)  
    CMP RAX, 1; si es menor
    JE .menor
    JMP .mayorOigual

.menor: ; avanza al siguiente nodo
    MOV R14, [R14 + OFFSET_L_E_NEXT]
    JMP .loop

.mayorOigual: ; debe insertarlo
    ; en R14 tengo la pos de mem del nodo actual
    MOV R10, [R14 + OFFSET_L_E_PREV]; consigo el anterior
    CMP R10, NULL; veo si estoy parado en el primer nodo.
    JNE .noEsPrimero
    ; si es primero, llamo a addFirst y termino
    MOV RDI, RBX
    MOV RSI, R12
    CALL listAddFirst
    JMP .fin

.noEsPrimero:
    ; pido mem para el nodo
    MOV RDI, L_E_SIZE
    call malloc
    ; conecto nodos adjacentes
    MOV [R10 + OFFSET_L_E_NEXT], RAX
    MOV [R14 + OFFSET_L_E_PREV], RAX
    ; relleno nodo insertado
    MOV [RAX + OFFSET_L_E_DATA], R12
    MOV [RAX + OFFSET_L_E_PREV], R10
    MOV [RAX + OFFSET_L_E_NEXT], R14

.fin:
    POP R15
    POP R14
    POP R13
    POP R12
    POP RBX
    RET



listRemove: ; listRemove(list_t* l, void* data, funcCmp_t* fc, funcDelete_t* fd)
    PUSH RBP
    MOV RBP, RSP
    SUB RSP, 32
    PUSH R12; para guardar nodo actual
    PUSH R13; guardar dato del nodo actual

    ; guardo los parametros en el stack frame
    MOV [RBP - 8], RDI; l
    MOV [RBP - 16], RSI; data
    MOV [RBP - 24], RDX; fc comp
    MOV [RBP - 32], RCX; fd del

    MOV R12, [RDI + OFFSET_L_FIRST] ; pos mem primer nodo

    CMP R12, NULL; veo si es lista vacia
    JNE .cmpNodo
    JMP .fin
    
.cmpNodo:
    MOV R13, [R12 + OFFSET_L_E_DATA]
    MOV RDI, [RBP - 16]; data parameter
    MOV RSI, R13; node->data
    MOV RDX, [RBP - 24]; func compare
    call RDX; hace compare
    CMP RAX, 0
    JNE .siguienteNodo

    ; borro nodo y engancho
    MOV R8, [R12 + OFFSET_L_E_PREV]; veo prev
    MOV R9, [R12 + OFFSET_L_E_NEXT]; veo next
    MOV R10, [RBP - 8]; l pos mem de la lista

    ;veo los 4 casos posibles para extirpar el nodo
    CMP R8, NULL
    JE .noPrev
    CMP R9, NULL
    JE .siPrevNoNext
    JMP .siPrevSiNext
.noPrev:
    CMP R9, NULL
    JE .noPrevNoNext
    JMP .noPrevSiNext

; engancho los nodos/lista sacando el actual..
.siPrevSiNext:
    MOV [R8 + OFFSET_L_E_NEXT], R9
    MOV [R9 + OFFSET_L_E_PREV], R8
    JMP .limpiar

.noPrevNoNext:
    MOV QWORD[R10 + OFFSET_L_FIRST], NULL
    MOV QWORD[R10 + OFFSET_L_LAST], NULL
    JMP .limpiar

.siPrevNoNext:
    MOV QWORD[R8 + OFFSET_L_E_NEXT], NULL
    MOV [R10 + OFFSET_L_LAST], R8
    JMP .limpiar
    
.noPrevSiNext:
    MOV QWORD[R10 + OFFSET_L_FIRST], R9
    MOV QWORD[R9 + OFFSET_L_E_PREV], NULL
    JMP .limpiar

.limpiar:
    MOV RCX, [RBP - 32] ; recupero delete
    CMP RCX, NULL
    JE .sinDelete
    MOV RDI, [R12 + OFFSET_L_E_DATA]; busco la data del nodo actual
    call RCX; llamo delete en data
.sinDelete:
    MOV RDI, R12
    MOV R12, [R12 + OFFSET_L_E_NEXT] ; setea siguiente nodo
    call free; llamo free en el NodoActual
    CMP R12, NULL; me fijo si termine.
    JNE .cmpNodo
    JMP .fin
    
.siguienteNodo:
    MOV R12, [R12 + OFFSET_L_E_NEXT]
    CMP R12, NULL
    JNE .cmpNodo
    JMP .fin

.fin:
    POP R13
    POP R12
    ADD RSP, 32
    POP RBP
    ret

listRemoveFirst: ;listRemoveFirst(list_t* l, funcDelete_t* fd)
    MOV R10, [RDI + OFFSET_L_FIRST]; pos mem First
    CMP R10, NULL; lista vacia
    JNE .novacia
    RET
.novacia:
    MOV R11, [R10 + OFFSET_L_E_NEXT]; pos mem First->Next
    CMP R11, NULL
    JE .removerUnico
    JMP .removerNoUnico

.removerUnico:
    MOV QWORD[RDI + OFFSET_L_FIRST], NULL
    MOV QWORD[RDI + OFFSET_L_LAST], NULL
    JMP .remover
    
.removerNoUnico:
    MOV QWORD[RDI + OFFSET_L_FIRST], R11; First ahora es el second
    MOV QWORD[R11 + OFFSET_L_E_PREV], NULL
    JMP .remover

.remover:
    PUSH R10
    MOV RDI, [R10 + OFFSET_L_E_DATA]; muevo el data para borrar.
    CMP RSI, NULL
    JE .nullDelete
    call RSI; llama a funcDelete(RDI)
.nullDelete:
    POP R10
    MOV RDI, R10
    JMP free

listRemoveLast:
    MOV R10, [RDI + OFFSET_L_LAST]; pos mem Last
    CMP R10, NULL; lista vacia
    JNE .novacia
    RET
.novacia:
    MOV R11, [R10 + OFFSET_L_E_PREV]; pos mem Last->Prev
    CMP R11, NULL
    JE .removerUnico
    JMP .removerNoUnico
.removerUnico:
    MOV QWORD[RDI + OFFSET_L_FIRST], NULL
    MOV QWORD[RDI + OFFSET_L_LAST], NULL
    JMP .remover

.removerNoUnico:
    MOV QWORD[RDI + OFFSET_L_LAST], R11; Last ahora es el Prev
    MOV QWORD[R11 + OFFSET_L_E_NEXT], NULL
    JMP .remover

.remover:
    PUSH R10
    MOV RDI, [R10 + OFFSET_L_E_DATA]; muevo el data para borrar.
    CMP RSI, NULL
    JE .nullDelete
    call RSI; llama a funcDelete(RDI)
.nullDelete:
    POP R10
    MOV RDI, R10
    JMP free

listDelete: ;void listDelete(list_t* l, funcDelete_t* fd)
    PUSH R12; uso para nodo actual
    PUSH RBX; uso para funcDelete
    PUSH R13; guardo referencia lista

    MOV R13, RDI
    MOV RBX, RSI; guardo funcDelete
    MOV R12, [RDI + OFFSET_L_FIRST]; first si exist

.loop:
    CMP R12, NULL
    JE .fin
    MOV RDI, [R12 + OFFSET_L_E_DATA]; pos mem del data
    CMP RBX, NULL
    JE .borrarNulo
    CALL RBX; funcDelete(RDI) libero el data
.borrarNulo:
    MOV RDI, R12
    MOV R12, [R12 + OFFSET_L_E_NEXT]
    call free; libero el nodo 
    jmp .loop;

.fin:
    MOV RDI, R13
    call free;
    POP R13
    POP RBX
    POP R12
    RET
    
listPrint: ;listPrint(list_t* l, FILE *pFile, funcPrint_t* fp)
    PUSH R12; uso para nodo actual
    PUSH RBX; uso para funcPrint_t
    PUSH R13; uso para pFile
    
    MOV R12, [RDI + OFFSET_L_FIRST]; first
    MOV R13, RSI
    MOV RBX, RDX

    MOV RDX, stringFormat
    MOV RSI, bracketListIni
    MOV RDI, R13
    call fprintf; imprimo [

    CMP RBX, NULL
    JE .loop1
    JMP .loop2

.loop1:
    CMP R12, NULL
    JE .fin

    MOV RDX, [R12 + OFFSET_L_E_DATA]; pos mem del data
    MOV RDI, R13
    MOV RSI, pointerFormat
    call fprintf; llamo fprintf para el nodo->data actual
    MOV R12, [R12 + OFFSET_L_E_NEXT]; avanzo

    CMP R12, NULL
    JE .loop1

    ; print comma
    MOV RDX, stringFormat
    MOV RSI, comma
    MOV RDI, R13
    call fprintf; imprimo , 

    JMP .loop1

.loop2:
    CMP R12, NULL
    JE .fin

.noComma2:
    MOV RDI, [R12 + OFFSET_L_E_DATA]; pos mem del data
    MOV RSI, R13
    call RBX; llamo print para el nodo->data actual
    MOV R12, [R12 + OFFSET_L_E_NEXT]; avanzo
    CMP R12, NULL
    JE .loop2

    ; print comma
    MOV RDX, stringFormat
    MOV RSI, comma
    MOV RDI, R13
    call fprintf; imprimo , 

    JMP .loop2

.fin:

    MOV RDX, stringFormat
    MOV RSI, bracketListFin
    MOV RDI, R13
    call fprintf; imprimo ]

    POP R13
    POP RBX
    POP R12
    RET


;;;;;;;;;;;;;;;;;;;;;;
;;      TREE        ;;
;;;;;;;;;;;;;;;;;;;;;;

n3treeNew:
    MOV RDI, T_SIZE
    SUB RSP, 8; alineacion
    call malloc
    ADD RSP, 8
    MOV QWORD[RAX + OFFSET_T_FIRST], NULL
    RET

n3treeAdd: ; void n3treeAdd(n3tree_t* t, void* data, funcCmp_t* fc)
    ; DOC: Ver enunciado TP1

    ; pusheo registros que quiero usar y debo preservar. Y dejo alineado el stack a 16
    PUSH RBX
    PUSH R12
    PUSH R13
    PUSH R14
    PUSH R15

    ; guardo entrada en estos
    MOV RBX, RDI;   tree
    MOV R12, RSI;   data
    MOV R13, RDX;   func fc

    ; veo si es tree vacio
    MOV R14, [RDI + OFFSET_T_FIRST];    R14 lo uso para guardar pos mem TreeElem
    CMP R14, NULL
    JNE .treeElemNoVacio
    
    ; caso vacio
    MOV RDI, R12;   muevo data
    call .funNewTreeElem;   nuevo tree elem con data
    MOV [RBX + OFFSET_T_FIRST], RAX;    muevo en tree->first el TreeElem(data)
    JMP .fin; retorno es void

.treeElemNoVacio:
    ; comparo datos. en R14 tengo treeElem actual no NULL
    MOV RDI, [R14 + OFFSET_T_E_DATA]
    MOV RSI, R12
    call R13;   comparacion fc(te->data, data)
    CMP RAX, 0
    JE .centerAdd;  0 -> data = te->data
    JL .leftAdd;    -1 -> data < te->data
    JG .rightAdd;   1 -> data > te->data

.centerAdd:
    ; agrego a la lista center del nodo actual
    MOV RDI, [R14 + OFFSET_T_E_CENTER];     consigo la lista
    MOV RSI, R12;   consigo el data
    MOV RDX, R13;   consigo el fc
    CALL listAdd;   void listAdd(list_t* l, void* data, funcCmp_t* fc)
    JMP .fin

.leftAdd:
    ; me fijo si rama left vacia o no
    MOV RDX, R14;   guardo referencia nodo actual
    MOV R14, [R14 + OFFSET_T_E_LEFT];     consigo te left
    CMP R14, NULL;
    JNE .treeElemNoVacio; itero sobre rama left

    ; caso vacio:
    MOV R14, RDX;   recupero referencia nodo
    MOV RDI, R12;   muevo data
    call .funNewTreeElem;   nuevo tree elem con data
    MOV [R14 + OFFSET_T_E_LEFT], RAX;    muevo en tree->first el TreeElem(data)
    JMP .fin; retorno es void

.rightAdd:
    ; me fijo si rama right vacia o no
    MOV RDX, R14;   guardo referencia nodo actual
    MOV R14, [R14 + OFFSET_T_E_RIGHT];     consigo te left
    CMP R14, NULL;
    JNE .treeElemNoVacio; itero sobre rama right

    ; caso vacio:
    MOV R14, RDX;   recupero referencia nodo
    MOV RDI, R12;   muevo data
    call .funNewTreeElem;   nuevo tree elem con data
    MOV [R14 + OFFSET_T_E_RIGHT], RAX;    muevo en tree->first el TreeElem(data)
    JMP .fin; retorno es void
    
.fin: 
    POP R15
    POP R14
    POP R13
    POP R12
    POP RBX
    RET    
    
.funNewTreeElem: 
    ; DOC: crea nuevo n3treeElem_t vacio, y agrega data pasado por parametro
    ; IN: RDI = void* data, 
    ; OUT: RAX = n3treeElem_t* 
    ;   + Con LEFT y RIGHT apuntando a 0, C una lista vacia, y data el pasado.

    ; pido memoria para n3treeElem_t
    PUSH RDI;   alineacion a 16, y guardo data
    MOV RDI, T_E_SIZE
    call malloc
    POP RDI
    
    ; seteo los punteros excepto center
    MOV [RAX + OFFSET_T_E_DATA], RDI;   data
    MOV QWORD[RAX + OFFSET_T_E_LEFT], NULL
    MOV QWORD[RAX + OFFSET_T_E_RIGHT], NULL

    ; seteo center
    PUSH RAX;   guardo pos mem del n3treeElem y alineo a 16
    call listNew
    MOV R10, RAX;   pos mem new lista vacia
    POP RAX
    MOV [RAX + OFFSET_T_E_CENTER], R10;     muevo pos mem lista vacia a n3treeElem

    RET

n3treeRemoveEq: ;   n3treeRemoveEq(n3tree_t* t, funcDelete_t* fd)
    ; DOC: Ver enunciado TP1

    ; guardo en RDI primer nodo
    MOV RDI, [RDI + OFFSET_T_FIRST];    guardar pos mem TreeElem primero   

.funRemoveEqTreeAux:
    ; DOC: recibe pos mem de nodo treeElem_t, llama funRemoveEqTreeElemList, y llama recursivamente en left y right
    ; IN: RDI = n3treeElem_t*, RSI = funcDelete_t* fd
    ; OUT: void
    
    ; me fijo si pos mem nodo es NULL
    CMP RDI, NULL
    JNE .auxContinuar
    RET ;   caso null, regreso

.auxContinuar:  
    ; caso no null
    PUSH RBX; alinea a 16
    PUSH R15
    SUB RSP, 8
    MOV RBX, RDI;   guardo nodo actual
    MOV R15, RSI;   guardo delete
    
    ; limpia lista nodo actual
    call .funRemoveEqTreeElemList;  limpio nodo actual

    ; recursion rama izquierda
    MOV RDI, [RBX + OFFSET_T_E_LEFT]
    MOV RSI, R15
    call .funRemoveEqTreeAux

    ; recursion rama derecha
    MOV RDI, [RBX + OFFSET_T_E_RIGHT]
    MOV RSI, R15
    call .funRemoveEqTreeAux

    ADD RSP, 8
    POP R15
    POP RBX
    RET
    
.funRemoveEqTreeElemList: 
    ; DOC: recibe pos mem de nodo treeElem_t, y le limpia la lista center
    ; IN: RDI = n3treeElem_t*, RSI = funcDelete_t* fd
    ; OUT: void

    ; consigo pos mem lista
    PUSH RBX;   alineacion 16, y uso para guardar ptr treeElem_t
    MOV RBX, RDI
    MOV RDI, [RBX + OFFSET_T_E_CENTER];     consigo lista
    
    ;veo si esta vacia
    MOV R10, [RDI + OFFSET_L_FIRST]
    CMP R10, NULL
    JNE .auxContinuarB
    POP RBX
    RET;    la lista esta vacia. Fin.

.auxContinuarB:
    ; no vacia -> borro
    call listDelete;    void listDelete(list_t* l, funcDelete_t* fd)

    ; creo una lista nueva y la pongo en center
    call listNew
    POP RBX; recupero nodo
    MOV [RBX + OFFSET_T_E_CENTER], RAX
    RET

n3treeDelete: ;n3treeDelete(n3tree_t* t, funcDelete_t* fd)
    ; DOC: ver enunciado TP1

    ; guardo en RDI primer nodo
    MOV R10, [RDI + OFFSET_T_FIRST];    guardar pos mem TreeElem primero   
    CMP R10, NULL
    JNE .noVacia
    CALL free;  libero memoria caso vacio. en RDI está t.
    RET

.noVacia:
    PUSH RDI;     guardo t, y alineacion a 16
    MOV RDI, R10
    call .funN3treeDeleteAux
    POP RDI
    SUB RSP, 8; alineacion 16
    CALL free;  libero memoria caso vacio. en RDI está t.
    ADD RSP, 8
    RET
    
.funN3treeDeleteAux:
    ; DOC: recibe ptr treeElem_t, limpia lista y data, y llama recursivamente en left y right
    ; IN: RDI = n3treeElem_t*, RSI = funcDelete_t* fd
    ; OUT: void
    CMP RDI, NULL
    JNE .noNuloAux
    RET
.noNuloAux:

    ; push registros que quiero usar y debo conservar
    PUSH R12
    PUSH RBX
    SUB RSP, 8
    
    MOV RBX, RDI;   nodo actual
    MOV R12, RSI;   delete func

    ; limpio lista
    MOV RDI, [RBX + OFFSET_T_E_CENTER];     consigo lista
    call listDelete;    void listDelete(list_t* l, funcDelete_t* fd)

    ; limpio data
    CMP RSI, NULL
    JE .sinDelete
    MOV RDI, [RBX + OFFSET_T_E_DATA];     consigo data
    call R12; llamo delete sobre ptr data

.sinDelete:
    ; recursion rama izquierda
    MOV RDI, [RBX + OFFSET_T_E_LEFT]
    MOV RSI, R12
    call .funN3treeDeleteAux

    ; recursion rama derecha
    MOV RDI, [RBX + OFFSET_T_E_RIGHT]
    MOV RSI, R12
    call .funN3treeDeleteAux

    ; libero memoria del nodo treeElem_t
    MOV RDI, RBX
    call free

    ADD RSP, 8
    POP RBX
    POP R12
    RET

;;;;;;;;;;;;;;;;;;;;;;
;;      TABLE       ;;
;;;;;;;;;;;;;;;;;;;;;;


nTableNew: ;    nTable_t* nTableNew(uint32_t size)
    ; DOC: ver enunciado TP1
    ; PRECONDICION: size * 8 entra en 32 bits

    ; push registros que quiero usar y debo preservar. Alineacion a 16.
    PUSH RBX;   size
    PUSH R14;   nTable_t*
    PUSH R15;   ptr a array de listas
    PUSH R13;   contador
    SUB RSP, 8

    ; guardo parametro. Y tambien limpio parte alta de RBX http://x86asm.net/articles/x86-64-tour-of-intel-manuals/
    MOV EBX, EDI
    
    ; pido memoria para struct nTable_t
    MOV RDI, TABLE_SIZE
    call malloc

    MOV R14, RAX;   guardo ptr en R14

    ; pido memoria para array ptr a list. size * 8
    LEA RDI, [0+RBX*8];
    call malloc

    MOV [R14 + OFFSET_TAB_L_ARRAY], RAX;    guardo en campo 1 del struct el ptr al array [ >64< | 32 32 ]
    MOV [R14 + OFFSET_TAB_SIZE], EBX;    guardo en campo 2 del struct el size 32 bits [ 64 | >32< 32 ]

    ; lleno con empty lists el array.
    MOV R15, [R14 + OFFSET_TAB_L_ARRAY]
    XOR R13, R13;   limpio contador
.loop:
    call listNew
    MOV [R15 + R13 * 8], RAX;   guardo new list
    INC R13
    CMP R13, RBX;   comparo con size
    JNE .loop

    ; fin
    MOV RAX, R14;   return nTable_t*
    ADD RSP, 8
    POP R13    
    POP R15
    POP R14
    POP RBX
    RET

nTableAdd: ; nTableAdd(nTable_t* t, uint32_t slot, void* data, funcCmp_t* fc)
    ; DOC: ver enunciado TP1

    ; guardo registro que quiero usar y debo preservar
    PUSH RBX

    MOV R10, [RDI + OFFSET_TAB_L_ARRAY];    array de listas
    MOV RBX, RDX;

    ; tomo modulo del slot... EDX:EAX dividendo
    MOV EAX, ESI;   limpio parte alta RAX, y guardo numero slot
    XOR RDX, RDX;   limpio RDX
    XOR R11, R11
    MOV R11d, [RDI + OFFSET_TAB_SIZE]; size array
    DIV R11d; me deja el remainder en EDX
    
    ; acceso a la lista y llamo a Add
    MOV RDI, [R10 + RDX*8];  lista
    MOV RSI, RBX;   data
    MOV RDX, RCX;  func cmp   
    call listAdd ; void listAdd(list_t* l, void* data, funcCmp_t* fc)

    POP RBX
    ret
    
nTableRemoveSlot: ; nTableRemoveSlot(nTable_t* t, uint32_t slot, void* data, funcCmp_t* fc, funcDelete_t* fd)
    ; DOC: ver enunciado TP1

    ; guardo registro que quiero usar y debo preservar
    PUSH RBX

    MOV R10, [RDI + OFFSET_TAB_L_ARRAY];    array de listas
    MOV RBX, RDX;

    ; tomo modulo del slot... EDX:EAX dividendo
    MOV EAX, ESI;   limpio parte alta RAX, y guardo numero slot
    XOR RDX, RDX;   limpio RDX
    XOR R11, R11
    MOV R11d, [RDI + OFFSET_TAB_SIZE]; size array
    DIV R11d; me deja el remainder en EDX
    
    ; acceso a la lista y llamo a listRemove
    MOV RDI, [R10 + RDX*8];  lista
    MOV RSI, RBX;   data
    MOV RDX, RCX;  func cmp
    MOV RCX, R8;    func del 
    call listRemove ; listRemove(list_t* l, void* data, funcCmp_t* fc, funcDelete_t* fd)

    POP RBX
    ret
    
nTableDeleteSlot: ;nTableDeleteSlot(nTable_t* t, uint32_t slot, funcDelete_t* fd)
    ; DOC: ver enunciado TP1

    ; guardo registro que quiero usar y debo preservar
    PUSH RBX
    PUSH R14
    PUSH R15

    MOV R15, RDI;   guardo el t
    MOV R10, [RDI + OFFSET_TAB_L_ARRAY];    array de listas
    MOV RBX, RDX;

    ; tomo modulo del slot... EDX:EAX dividendo
    MOV EAX, ESI;   limpio parte alta RAX, y guardo numero slot
    XOR RDX, RDX;   limpio RDX
    XOR R11, R11
    MOV R11d, [RDI + OFFSET_TAB_SIZE]; size array
    DIV R11d; me deja el remainder en EDX
    MOV R14, RDX; guardo el slot
    
    ; acceso a la lista y llamo a listDelete
    MOV RDI, [R10 + RDX*8];  lista
    MOV RSI, RBX;   func Del
    CALL listDelete;   listDelete(list_t* l, funcDelete_t* fd)

    ; meto en slot una vacia
    CALL listNew
    MOV R10, [R15 + OFFSET_TAB_L_ARRAY];    array de listas
    MOV [R10 + R14*8], RAX

    POP R15
    POP R14
    POP RBX
    RET

nTableDelete: ; nTableDelete(nTable_t* t, funcDelete_t* fd)
    ; DOC: ver enunciado TP1
    
    ; guardo registros que quiero usar y debo preservar
    PUSH RBX;   t
    PUSH R13;   t->listArray
    PUSH R14;   fun delete
    PUSH R15;   tab size counter
    SUB RSP, 8
    
    MOV RBX, RDI
    MOV R13, [RDI + OFFSET_TAB_L_ARRAY]; guardo pos mem lista de arrays
    MOV R14, RSI
    XOR R15, R15
    MOV R15d, [RDI + OFFSET_TAB_SIZE]
    DEC R15d
    
.loop:
    ; acceso a la lista y llamo a listDelete
    MOV RDI, [R13 + R15*8];  lista
    MOV RSI, R14;   func Del
    CALL listDelete;   listDelete(list_t* l, funcDelete_t* fd)
    DEC R15
    CMP R15, 0
    JGE .loop
    
    ; y ahora borro las estructuras restantes

    MOV RDI, R13;   libero array de listas
    call free

    MOV RDI, RBX;   libero struct
    call free

    ADD RSP, 8
    POP R15
    POP R14
    POP R13
    POP RBX
    ret
