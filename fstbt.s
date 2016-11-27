;fast boot-loader in one sector
;copyright (c) Peter Ferrie 2016
;thanks to 4am for inspiration and testing
;assemble using ACME
!cpu 6502
!to "fstbt",plain
*=$800

!byte 1

        tay                     ;A is last read sector+1 on entry

        ;2, 4, 6, 8, $0A, $0C, $0E
        ;because PROM increments by one itself
        ;and is too slow to read sectors in purely incremental order
        ;so we offer every other sector for read candidates

incsector
        iny
        cpy     #$10            ;set carry, needed for seek
        bcc     incindex        ;cases 1-$0F
        beq     sector1         ;finished with $0E
                                ;next should be 1 for 1, 3, 5, 7... sequence

        ;finished with $0F, now we are $11, so 16 sectors done

        jsr     seek            ;returns A=0

        ;back to 0

        tay
        !byte   $2C             ;mask LDY #1
sector1
        ldy     #1

incindex
        sty     $3d             ;set sector
        iny                     ;prepare to be next sector in case of unallocated sector
        inc     adrindex + 1    ;select next address

adrindex
        lda     adrtable - 1    ;15 entries in first row, 16 entries thereafter
        beq     incsector       ;skip empty slots to allow sparse tracks
        sta     $27             ;set high part of address
        tay
        iny
        beq     jmpoep          ;#$FF means end of data

        ;convert slot to PROM address

        txa
        lsr
        lsr
        lsr
        lsr
        ora     #$c0
        pha
        lda     #$5B            ;read-1
        pha
        rts                     ;return to PROM

        ;requires carry set on entry
        ;carry is set by cpy above
        ;and by wait below

seek
        inc     $41             ;next track
        jsr     seek1

seek1                           ;phase on
        inc     phase + 1

phase
        ldy     #0              ;self-modified
        jsr     delay
        clc                     ;phase off
        ldy     phase + 1
        dey

delay
        tya
        and     #3
        rol
        ora     $2B             ;merge in slot
        tay
        lda     $C080, y
        lda     #$30
        jmp     $FCA8           ;common delay for all phases

jmpoep
        jmp     $1234

adrtable
;15 slots for track 0 (track 0 sector 0 is not addressible)
;16 slots for all other tracks
!byte $FF ;end of list
