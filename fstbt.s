;fast boot-loader in one sector
;copyright (c) Peter Ferrie 2016
;thanks to 4am for inspiration and testing
;assemble using ACME
!cpu 6502
!to "fstbt",plain
*=$800

        enable_banked = 0       ;set to bank number (1 or 2) to enable reading into banked RAM

!byte 1

        tay                     ;A is last read sector+1 on entry
!if enable_banked > 0 {
        lda     $C081           ;bank in ROM
}

        ;check array before checking sector number
        ;allows us to avoid a redundant seek if all slots are full in a track,
        ;and then the list ends

incindex
        inc     adrindex + 1    ;select next address

adrindex
        lda     adrtable - 1    ;15 entries in first row, 16 entries thereafter
        cmp     #$C0
        beq     jmpoep          ;#$C0 means end of data
        sta     $27             ;set high part of address
        lda     #1              ;preload in case we are finished with the first round

        ;2, 4, 6, 8, $0A, $0C, $0E
        ;because PROM increments by one itself
        ;and is too slow to read sectors in purely incremental order
        ;so we offer every other sector for read candidates

        iny
        cpy     #$10
        bcc     setsector       ;cases 1-$0F
        beq     sector1         ;finished with $0E
                                ;next should be 1 for 1, 3, 5, 7... sequence

        ;finished with $0F, now we are $11, so 16 sectors done

        jsr     seek            ;returns A=0

        ;back to 0

sector1
        tay

setsector
        sty     $3D             ;set sector
        iny                     ;prepare to be next sector in case of unallocated sector
        lda     $27
        beq     incindex        ;empty slot, back to the top

        ;convert slot to PROM address

        txa
        jsr     $F87B           ;4xlsr
        ora     #$C0
        pha
        lda     #$5B            ;read-1
        pha

!if enable_banked > 0 {
writeenable
        lda     $C093-(enable_banked*8)
        lda     $C093-(enable_banked*8)
                                ;write-enable RAM and bank it in so read can decode
}
        rts                     ;return to PROM

seek
        inc     $41             ;next track
        asl     $40             ;carry clear, phase off
        jsr     seek1           ;returns carry set, not useful
        clc                     ;carry clear, phase off

seek1
        jsr     delay           ;returns with carry set, phase on
        inc     $40             ;next phase

delay
        lda     $40
        and     #3
        rol
        ora     $2B             ;merge in slot
        tay
        lda     $C080, y
        lda     #$30
        jmp     $FCA8           ;common delay for all phases

jmpoep
!if enable_banked > 0 {
        jsr     writeenable     ;bank in our RAM, write-enabled
}
        jmp     $1234           ;arbitrary entry-point to use after read completes
                                ;set to the value that you need

adrtable
;15 slots for track 0 (track 0 sector 0 is not addressable)
;16 slots for all other tracks, fill with addresses, 0 to skip any sector
!byte $C0 ;end of list
