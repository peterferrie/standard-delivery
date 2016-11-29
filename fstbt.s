;fast boot-loader in one sector
;copyright (c) Peter Ferrie 2016
;thanks to 4am for inspiration and testing
;assemble using ACME
!cpu 6502
!to "fstbt",plain
*=$800

        enable_stack = 0        ;set to 1 to enable reading into stack (mutually exclusive with enable_banked)
        enable_banked = 0       ;set to bank number (1 or 2) to enable reading into banked RAM

!if (enable_stack+enable_banked)=2 {
  !error can't enable both options
}

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
!if enable_banked=1 {
        lda     $C08B
        lda     $C08B
} else {
  !if enable_banked=2 {
        lda     $C083
        lda     $C083
  }
}

adrindex
        lda     adrtable - 1    ;15 entries in first row, 16 entries thereafter
        beq     incsector       ;skip empty slots to allow sparse tracks
        sta     $27             ;set high part of address
        tay
!if enable_banked=0 {
        iny                     ;detect #$FF (end of data)
} else {
        dey                     ;detect #$01 (end of data)
}
        beq     jmpoep          ;end of data

        ;convert slot to PROM address

        txa
        lsr
        lsr
        lsr
        lsr
        ora     #$C0
        pha
        lda     #$5B            ;read-1
        pha
        rts                     ;return to PROM

seek
        inc     $41             ;next track
        asl     $40             ;carry clear, phase off
        jsr     seek1
        clc                     ;carry clear, phase off

seek1
        jsr     delay           ;returns with carry set, phase on
        inc     $40

delay
        lda     $40
        and     #3
        rol
        ora     $2B             ;merge in slot
        tay
        lda     $C080, y
!if enable_banked = 1 {
        lda     $C089
} else {
  !if enable_banked = 2 {
        lda     $C081
  }
}
        lda     #$30
        jmp     $FCA8           ;common delay for all phases

jmpoep
        jmp     $1234           ;arbitrary entry-point to use after read completes
                                ;set to the value that you need

adrtable
;15 slots for track 0 (track 0 sector 0 is not addressable)
;16 slots for all other tracks, fill with addresses, 0 to skip any sector
!byte 1 ;end of list, can't load to stack
