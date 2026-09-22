\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   // ************************* BELOW PART TAKEN FROM EISTING CODE in GitHub ***********************************
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program for MYTH Workshop to test RV32I
   // Add 1,2,3,...,9 (in that order), store the sum to dmem, then load it back.
   //
   // Regs:
   //  r10 (a0): In: 0, Out: final sum
   //  r12 (a2): 10
   //  r13 (a3): 1..10
   //  r14 (a4): Sum
   //  r15:      loaded-back copy of the sum (dmem round trip)
   //  r7:       halt-loop link register (JAL target == itself)
   //
   // External to function:
   m4_asm(ADD, r10, r0, r0)             // Initialize r10 (a0) to 0.
   // Function:
   m4_asm(ADD, r14, r10, r0)            // Initialize sum register a4 with 0x0
   m4_asm(ADDI, r12, r10, 1010)         // Store count of 10 in register a2.
   m4_asm(ADD, r13, r10, r0)            // Initialize intermediate sum register a3 with 0
   // Loop:
   m4_asm(ADD, r14, r13, r14)           // Incremental addition
   m4_asm(ADDI, r13, r13, 1)            // Increment intermediate register by 1
   m4_asm(BLT, r13, r12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   m4_asm(ADD, r10, r14, r0)            // Store final result to register a0 so that it can be read by main program
   m4_asm(SW, r0, r10, 100)             // Store the sum to dmem[4]
   m4_asm(LW, r15, r0, 100)             // Load it back into r15 (round-trip check)
   // Halt loop (debug fix -- see writeup "Halt loop and instruction-memory padding" section):
   // the reference program has no way to stop PC from running off its own end, which -- given
   // a finite, power-of-2-sized IMEM -- eventually WRAPS BACK to address 0 and silently re-runs
   // (and re-corrupts) the whole program. A JAL-to-self is added, with NOPs on BOTH sides: 3
   // before it, so its own 3-cycle flush window doesn't overlap the immediately preceding load's;
   // and a generous 14 after it, because the self-loop's steady state doesn't settle into a tight
   // single-flush-and-return -- it free-runs several words past the JAL before each redirect
   // lands (confirmed empirically: up to 5 words past JAL, periodically, forever, once settled).
   // Without enough trailing NOPs those excursions run past the program into un-asm'd (zero)
   // memory, which decodes as an illegal, out-of-range "instruction" -- harmless in practice
   // (its rd field is r0, so the write-enable's "$rd != 0" check blocks it from ever committing),
   // but it would still trip $illegal_instr / $pc_out_of_range forever in the halted steady
   // state and fail the simulation. Padding the tail keeps every excursion inside real,
   // legal NOPs that are counted in M4_NUM_INSTRS, so none of the error signals ever fire once
   // the program has settled.
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(JAL, r7, 0)                   // Halt: jump to self, forever.
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP
   m4_asm(ADD, r0, r0, r0)              // NOP (17 NOPs total -- pads M4_NUM_INSTRS to 28,
                                         // comfortably covering the deepest observed excursion.)
   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)
   // ************************* ABOVE PART TAKEN FROM EXISTING CODE in GitHub *********************************** 
   
   |cpu
      @0
         $reset = *reset;
         // ---- Lab instruction 2 (increment PC every cycle, not every 3): already satisfied --
         // the default (no-redirect) term below is ">>1$pc + 4", a plain 1-cycle bare delay, so
         // a new PC issues every single cycle, continuously, with no throttling. No change here.
         // ---- Lab instruction 3 (PC redirect for branches is already 3-cycle): also already
         // satisfied structurally -- the redirect terms below all key off an explicit >>3, so a
         // taken branch/jalr/load redirects exactly 3 cycles after the causing instruction's own
         // @3, unchanged from the reference. What DOES change (debug fixes, instruction 4) is
         // *what* feeds these >>3 terms: validity-gated signals instead of raw ones -- see bug D
         // below, right where $valid_jalr / $valid_taken_br / $valid_is_load are defined.
         $pc[31:0] = (>>1$reset)     ? 32'd0 :
                     (>>3$valid_jalr)     ? (>>3$jalr_tgt_pc) :
                     (>>3$valid_taken_br) ? (>>3$br_tgt_pc) :
                     (>>3$valid_is_load)  ? (>>3$pc + 32'd4) :
                                            (>>1$pc + 32'd4);
      @1
         $imem_rd_addr[(M4_IMEM_INDEX_CNT-1):0] = $pc[(M4_IMEM_INDEX_CNT+1):2];
         $imem_rd_en = ! $reset;
         $instr[31:0] = $imem_rd_en ? $imem_rd_data[31:0] : 32'b0 ;
         $is_i_instr =  ($instr[6:2] ==? 5'b0000x) || ($instr[6:2] ==? 5'b001x0) || ($instr[6:2] ==? 5'b11001) || ($instr[6:2] ==? 5'b11100);
         $is_r_instr = ($instr[6:2] ==? 5'b01011) || ($instr[6:2] ==? 5'b011x0) || ($instr[6:2] ==? 5'b10100);
         $is_s_instr = ($instr[6:2] ==? 5'b0100x);
         $is_b_instr = ($instr[6:2] ==? 5'b11000);
         $is_j_instr = ($instr[6:2] ==? 5'b11011);
         $is_u_instr = ($instr[6:2] ==? 5'b0x101);
         $imm[31:0] = $is_i_instr ? {{21{$instr[31]}},$instr[30:20]} : ($is_s_instr ? {{21{$instr[31]}},$instr[30:25],$instr[11:7]} :
                      ($is_b_instr ? {{20{$instr[31]}},$instr[7],$instr[30:25],$instr[11:8],1'b0} : ($is_u_instr ? {$instr[31:12],12'b0} :
                      ($is_j_instr ? {{12{$instr[31]}},$instr[19:12],$instr[20],$instr[30:21],1'b0} : 32'b0))));
         $funct7_valid = $is_r_instr;
         ?$funct7_valid
            $funct7[6:0] = $instr[31:25];
         $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
         ?$rs2_valid
            $rs2[4:0] = $instr[24:20];
         $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         ?$rs1_valid
            $rs1[4:0] = $instr[19:15];
         $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         ?$funct3_valid
            $funct3[2:0] = $instr[14:12];
         $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
         ?$rd_valid
            $rd[4:0] = $instr[11:7];
         $opcode[6:0] = $instr[6:0];
         $dec_bits[10:0] = {$funct7[5], $funct3, $opcode};
         $is_lui = $dec_bits ==? 11'bx_xxx_0110111;
         $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
         $is_jal = $dec_bits ==? 11'bx_xxx_1101111;
         $is_jalr = $dec_bits ==? 11'bx_000_1100111;
         $is_beq = $dec_bits ==? 11'bx_000_1100011;
         $is_bne = $dec_bits ==? 11'bx_001_1100011;
         $is_blt = $dec_bits ==? 11'bx_100_1100011;
         $is_bge = $dec_bits ==? 11'bx_101_1100011;
         $is_bltu = $dec_bits ==? 11'bx_110_1100011;
         $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
         $is_load = $opcode == 7'b0000011;
         $is_sb = $dec_bits ==? 11'bx_000_0100011;
         $is_sh = $dec_bits ==? 11'bx_001_0100011;
         $is_sw = $dec_bits ==? 11'bx_010_0100011;
         $is_addi = $dec_bits ==? 11'bx_000_0010011;
         $is_slti = $dec_bits ==? 11'bx_010_0010011;
         $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
         $is_xori = $dec_bits ==? 11'bx_100_0010011;
         $is_ori = $dec_bits ==? 11'bx_110_0010011;
         $is_andi = $dec_bits ==? 11'bx_111_0010011;
         $is_slli = $dec_bits ==? 11'b0_001_0010011;
         $is_srli = $dec_bits ==? 11'b0_101_0010011;
         $is_srai = $dec_bits ==? 11'b1_101_0010011;
         $is_add = $dec_bits ==? 11'b0_000_0110011;
         $is_sub = $dec_bits ==? 11'b1_000_0110011;
         $is_sll = $dec_bits ==? 11'b0_001_0110011;
         $is_slt = $dec_bits ==? 11'b0_010_0110011;
         $is_sltu = $dec_bits ==? 11'b0_011_0110011;
         $is_xor = $dec_bits ==? 11'b0_100_0110011;
         $is_srl = $dec_bits ==? 11'b0_101_0110011;
         $is_sra = $dec_bits ==? 11'b1_101_0110011;
         $is_or = $dec_bits ==? 11'b0_110_0110011;
         $is_and = $dec_bits ==? 11'b0_111_0110011;

      @2
         $rf_rd_en1 = $rs1_valid;
         $rf_rd_index1[4:0] = $rs1;
         $rf_rd_en2 = $rs2_valid;
         $rf_rd_index2[4:0] = $rs2;
         // $rf_rd_data1/2 (raw, unforwarded RF read) come straight from m4+rf(@2,@3) below --
         // the bypass network that turns this raw read into $src1_value/$src2_value now lives
         // entirely in @3 (see bug B there), so this stage is unchanged from the reference.

      @3
         // ---- bug B fix: two-source register-file bypass, computed here at @3 (not @2) ----
         // The reference's bypass ("((>>1$rf_wr_en) && ((>>1$rd) == $rs1)) ? (>>1$result) :
         // $rf_rd_data1") is written at @2 and mixes two DIFFERENT instructions' fields under
         // one explicit >>1: $rf_wr_en/$result are home @3, so >>1 (from @2's own absolute
         // cycle) reaches the write that landed 1 cycle before THIS reader's @2 -- but $rd is
         // home @1, so >>1$rd is NOT that same writer's rd, it is this reader's OWN rd (decoded
         // the same cycle). It also only ever reaches one prior writer, 2 instructions back --
         // it has no path at all for the immediately PRECEDING instruction, whose write and this
         // reader's own register-read land in the very same absolute cycle (a same-cycle,
         // later-stage-to-earlier-stage dependency that a stage-@2 mux cannot express with plain
         // >>N syntax). This program needs BOTH: e.g. "ADD r13,r10,r0" -> "ADD r14,r13,r14" is
         // the immediately-adjacent case, while "ADD r13,r10,r0" -> "ADDI r13,r13,1" is the
         // 2-instructions-back case.
         //
         // Fix: move the whole bypass to @3, where it's naturally consumed as an ALU input
         // anyway. From @3, explicit >>1/>>2 on $rf_wr_en/$rf_wr_index/$rf_wr_data (all home @3)
         // correctly reach the immediately-preceding instruction's write (1 cycle back) and the
         // one before that (2 cycles back) respectively -- ordinary, always-legal explicit
         // delays, no same-cycle idiom needed. $rs1/$rs2 (home @1) and $rf_rd_data1/2 (home @2)
         // are read here via their own ordinary auto (bare) delays of 2 and 1.
         $src1_value[31:0] = ((>>1$rf_wr_en) && ((>>1$rf_wr_index) == $rs1) && ((>>1$rf_wr_index) != 5'b0)) ? (>>1$rf_wr_data) :
                              ((>>2$rf_wr_en) && ((>>2$rf_wr_index) == $rs1) && ((>>2$rf_wr_index) != 5'b0)) ? (>>2$rf_wr_data) :
                              $rf_rd_data1;
         $src2_value[31:0] = ((>>1$rf_wr_en) && ((>>1$rf_wr_index) == $rs2) && ((>>1$rf_wr_index) != 5'b0)) ? (>>1$rf_wr_data) :
                              ((>>2$rf_wr_en) && ((>>2$rf_wr_index) == $rs2) && ((>>2$rf_wr_index) != 5'b0)) ? (>>2$rf_wr_data) :
                              $rf_rd_data2;

         $result[31:0] = $is_andi  ? ($src1_value & $imm) :
                         $is_ori   ? ($src1_value | $imm) :
                         $is_xori  ? ($src1_value ^ $imm) :
                         $is_addi  ? ($src1_value + $imm) :
                         $is_slli  ? ($src1_value << $imm[5:0]) :
                         $is_srli  ? ($src1_value >> $imm[5:0]) :
                         $is_and   ? ($src1_value & $src2_value) :
                         $is_or    ? ($src1_value | $src2_value) :
                         $is_xor   ? ($src1_value ^ $src2_value) :
                         $is_srai  ? ({{32{$src1_value[31]}}, $src1_value} >> $imm[4:0]) :
                         $is_slt   ? (($src1_value[31] == $src2_value[31]) ? ($src1_value < $src2_value) : {31'b0, $src1_value[31]}) :
                         $is_slti  ? (($src1_value[31] == $imm[31]) ? ($src1_value < $imm) : {31'b0, $src1_value[31]}) :
                         $is_sra   ? ({{32{$src1_value[31]}}, $src1_value} >> $src2_value[4:0]) :
                         $is_add   ? ($src1_value + $src2_value) :
                         $is_sub   ? ($src1_value - $src2_value) :
                         $is_sll   ? ($src1_value << $src2_value[4:0]) :
                         $is_srl   ? ($src1_value >> $src2_value[4:0]) :
                         $is_sltu  ? ($src1_value < $src2_value) :
                         $is_sltiu ? ($src1_value < $imm) :
                         $is_lui   ? ({$imm[31:12], 12'b0}) :
                         $is_auipc ? ($pc + $imm) :
                         $is_jal   ? ($pc + 32'd4) :
                         $is_jalr  ? ($pc + 32'd4) :
                         $is_load ? ($src1_value + $imm) :
                         $is_s_instr ? ($src1_value + $imm) : 32'bx;

         $taken_br = $is_j_instr ? 1'b1 : (! $is_b_instr) ? 1'b0 : $is_beq ? ($src1_value == $src2_value) : $is_bne ? ($src1_value != $src2_value) :
                     $is_blt ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
                     $is_bge ? (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
                     $is_bltu ? ($src1_value < $src2_value) :  $is_bgeu ? ($src1_value >= $src2_value) : 1'b0;

         // ---- $valid: bugs E + H (compounding) ----
         // Bug E part 1 (home-stage mismatch): $is_load/$is_jalr are home @1; checked here at
         // @3, their OWN auto (bare) delay is already (3-1)=2 -- so the reference's literal
         // ">>1$is_load"/">>2$is_load" never reach anything earlier than THIS row's own
         // instruction (>>2 lands exactly ON it), permanently invalidating every load's own
         // execution and permanently zeroing $dmem_rd_en (= $valid && $is_load) in the literal
         // reference. Fix: check with >>3/>>4/>>5 (i.e. 2 more cycles beyond the built-in
         // auto-delay of 2) to reach 1/2/3 instructions BEFORE this row's own.
         // Bug E part 2 (window width): the @0 PC mux redirects with an explicit >>3, so exactly
         // THREE wrong-path instructions are fetched after any taken branch/jalr/load before the
         // corrected fetch lands (confirmed directly in simulation) -- $valid's window must
         // therefore be 3 slots wide, not 2, to match.
         // Bug H (missing validity gating on the window's own inputs): checking raw
         // is_load/is_jalr/taken_br 1..3 slots back means a wrong-path (already-flushed)
         // instruction that merely DECODES as a load/jalr/branch still re-arms this same 3-slot
         // flush window, cascading extra invalidation onto instructions that were already
         // correctly redirected. Concretely: right after a taken branch, the 3 speculatively
         // fetched wrong-path instructions can themselves include the program's real load or a
         // stale branch -- confirmed directly: the loop body kept losing validity on every
         // iteration because a wrong-path LW re-fetched 3 slots after each branch re-armed the
         // is_load window on top of the branch's own window, and (separately, once that was
         // fixed) a wrong-path re-decode of the loop's own BLT re-triggered a bogus taken-branch
         // redirect. Fix: gate each term by the validity of the instruction that set it --
         // $valid_taken_br / $valid_is_load / $valid_jalr (defined right below, already
         // expressed in "slots behind this row" terms) instead of the raw flags.
         $valid = !(>>1$valid_taken_br) && !(>>2$valid_taken_br) && !(>>3$valid_taken_br) &&
                  !(>>1$valid_is_load)  && !(>>2$valid_is_load)  && !(>>3$valid_is_load)  &&
                  !(>>1$valid_jalr)     && !(>>2$valid_jalr)     && !(>>3$valid_jalr);

         // ---- bug D fix: validity-qualified versions of taken_br/is_load/is_jalr, used both
         // by the @0 PC mux (so a wrong-path load/jalr/branch can no longer trigger a spurious
         // redirect -- the reference's mux checks the raw flags with no $valid qualification at
         // all) and by $valid's own window above (bug H). ----
         $valid_taken_br = $valid && $taken_br;
         $valid_is_load  = $valid && $is_load;   // $is_load here is bare (auto-delay 2) = this row's own
         $valid_jalr     = $valid && $is_jalr;   // $is_jalr here is bare (auto-delay 2) = this row's own

         // bug C fix: $br_tgt_pc moved here to @3 (the reference computes it at @2), so the @0
         // mux's shared explicit >>3 on $br_tgt_pc and $valid_taken_br now reads BOTH from the
         // same instruction -- with $br_tgt_pc left at @2, that same >>3 pulled the branch
         // target from a DIFFERENT (later) instruction than the one whose taken-decision it was
         // paired with, a one-instruction misalignment that silently redirected the PC to the
         // wrong address (the same class of bug as the earlier 3-cycle-pipeline lab).
         $br_tgt_pc[31:0] = $pc + $imm;
         $jalr_tgt_pc[31:0] = $src1_value + $imm;

         $ld_data[31:0] = >>2$dmem_rd_data;

         // ---- bugs F + G fix: the deferred load write-back ----
         // The reference's OR term for $rf_wr_en is literally ">>2$is_load" with NO validity
         // check -- by the SAME home-stage arithmetic as bug E, that explicit >>2 collapses to
         // THIS row's own (possibly wrong-path, possibly invalid) is_load, unconditional on
         // whether that load was ever valid: a flushed/wrong-path load still forced a garbage
         // write into the register file 2 cycles later (confirmed: a wrong-path LW re-fetched
         // every loop iteration kept firing a spurious write with data=0). Separately (bug G),
         // even once gated by validity, the TIMING of all three signals in this mux needs
         // re-deriving from scratch: call Tx the load's own @3 cycle. dmem itself is read at @4
         // (1 cycle later); $ld_data reads that via ITS OWN explicit >>2, so $ld_data is only
         // correct 2 cycles after that, i.e. at row Tx+3. Separately, the PC-mux's is_load
         // redirect invalidates exactly rows Tx+1..Tx+3 and nothing past Tx+3 -- so Tx+3 is the
         // LAST invalid/bubble row, and the first correctly-refetched (valid again) instruction
         // lands at Tx+4, doing its own register read at Tx+3. For that re-fetch to see the
         // loaded value already committed, the deferred write MUST land AT Tx+3 -- exactly the
         // row where $ld_data is already correct. So $rf_wr_data's invalid-branch term must read
         // $ld_data BARE (same row), not through a second explicit >>2 (the reference's literal
         // ">>2$ld_data" double-delays it to Tx+5, two cycles past the end of the invalid window
         // -- by then $valid is back to 1 for an unrelated real instruction, so the mux's $valid
         // branch wins and the deferred data is silently dropped; confirmed empirically: with
         // ">>2$ld_data" kept literal, the load's destination register never got written at all).
         // And $rf_wr_index's invalid-branch ">>2$rd" collapses (same bug-E-style home-stage
         // arithmetic) to THIS row's own rd, not the deferred load's rd; at row Tx+3 the load's
         // own rd was decoded at its own @1 = Tx-2, so the needed explicit delay is
         // (Tx+3)-(Tx-2) = 5, i.e. >>5$rd, not >>2$rd. Finally, $rf_wr_en's OR term must fire at
         // that same row Tx+3: $valid_is_load is 1 at row Tx, so >>3$valid_is_load lands exactly
         // there, matching the corrected index/data timing.
         $rf_wr_en = (($rd != 5'b00000) && $valid && $rd_valid && !$is_load) || (>>3$valid_is_load);
         $rf_wr_index[4:0] = $valid ? $rd : (>>5$rd);
         $rf_wr_data[31:0] = $valid ? $result : $ld_data;

         $dmem_rd_en = $valid && $is_load;
         $dmem_wr_en = $valid && $is_s_instr;
         $dmem_addr[3:0] = $result[5:2];
         $dmem_wr_data[31:0] = $src2_value;

         // ---- error handling (debug fix, lab instruction 4) ----
         // $illegal_instr: any fetched instruction outside the full RV32I subset this decoder
         // supports, checked only when $valid (most fetched "instructions" in a continuously
         // flushed/refetched design are wrong-path by construction, not just during reset).
         $illegal_instr = $valid && !($is_lui || $is_auipc || $is_jal || $is_jalr ||
                                       $is_beq || $is_bne || $is_blt || $is_bge || $is_bltu || $is_bgeu ||
                                       $is_load || $is_sb || $is_sh || $is_sw ||
                                       $is_addi || $is_slti || $is_sltiu || $is_xori || $is_ori || $is_andi ||
                                       $is_slli || $is_srli || $is_srai ||
                                       $is_add || $is_sub || $is_sll || $is_slt || $is_sltu || $is_xor || $is_srl || $is_sra || $is_or || $is_and);
         // $misaligned_tgt: a taken branch/JAL target is aligned by construction (immediate's
         // LSB is forced 0), so this only ever matters for JALR (register + immediate, not
         // inherently aligned) -- kept for both, defensively.
         $misaligned_tgt = ($valid_taken_br && ($br_tgt_pc[1:0] != 2'b00)) ||
                            ($valid_jalr     && ($jalr_tgt_pc[1:0] != 2'b00));
         // $tgt_out_of_range: a taken branch/JALR whose target word-index falls outside the
         // program. Qualified by $valid_taken_br / $valid_jalr, which already imply $valid.
         $tgt_out_of_range = ($valid_taken_br && ($br_tgt_pc[31:2] >= M4_NUM_INSTRS)) ||
                              ($valid_jalr     && ($jalr_tgt_pc[31:2] >= M4_NUM_INSTRS));
         // $pc_out_of_range: this valid instruction's own PC has run past the last instruction
         // (should never fire once the halt loop is reached -- see the halt-loop note above).
         $pc_out_of_range = $valid && ($pc[31:2] >= M4_NUM_INSTRS);
         $error = $illegal_instr || $misaligned_tgt || $tgt_out_of_range || $pc_out_of_range;

         *passed = |cpu/xreg[15]>>5$value == (1+2+3+4+5+6+7+8+9);
         // *failed fix: SandPiper rejects a bare "|cpu$error" referenced from OUTSIDE |cpu (a
         // cross-pipeline reference needs an explicit >>N alignment -- "Cross-pipeline signal
         // references require explicit alignment", followed by a same-cycle EARLY-USE error
         // once it assumes zero). *passed already shows the working pattern one line up: a
         // top-level "*" signal can be assigned right here, textually inside |cpu's @3 block,
         // alongside the $signals it reads -- so $error needs no cross-pipe delay at all, just
         // a bare same-scope reference. *cyc_cnt > 6 guards against the pipeline flops not
         // having loaded yet in the first few cycles, so $error can't show a stale/blank-derived
         // value there and end the simulation on a blank waveform (same guard as the prior lab).
         *failed = $error && (*cyc_cnt > 6);

      // Note: Because of the magic we are using for visualisation, if visualisation is enabled below,
      //       be sure to avoid having unassigned signals (which you might be using for random inputs)
      //       other than those specifically expected in the labs. You'll get strange errors for these.

   // Macro instantiations for:
   //  o instruction memory
   //  o register file
   //  o data memory
   //  o CPU visualization
   |cpu
      m4+imem(@1)    // Args: (read stage)
      m4+rf(@2, @3)  // Args: (read stage, write stage) - if equal, no register bypass is required
      m4+dmem(@4)    // Args: (read/write stage)

   m4+cpu_viz(@4)    // For visualisation, argument should be at least equal to the last stage of CPU logic. @4 would work for all labs.
\SV
   endmodule