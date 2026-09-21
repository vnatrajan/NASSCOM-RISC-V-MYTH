\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   // ************************* BELOW PART TAKEN FROM EXISTING CODE in GitHub ***********************************
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program for MYTH Workshop to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  r10 (a0): In: 0, Out: final sum
   //  r12 (a2): 10
   //  r13 (a3): 0..10
   //  r14 (a4): Sum
   //  r7  (t2): JAL link register (return address of the final halt loop)
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
   // ************************* ABOVE PART TAKEN FROM EXISTING CODE in GitHub ***********************************
   
   // Halt: jump to itself (infinite loop) so the PC never runs past the end of the
   // program and the result in r10 is not overwritten by the program restarting.
   m4_asm(JAL, r7, 00000000000000000000)
   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)
   |cpu
      @0
         // ---- PC (mux + "+1"; the increment is +4 because instructions are 4 bytes) ----
         $reset = *reset;
         // Reset -> 0.  Branch/jump taken last cycle -> target.  Otherwise PC + 4.
         $pc[31:0] = (>>1$reset) ? 32'd0 :
                     (>>1$pc_redirect) ? (>>1$br_tgt_pc) :
                     (>>1$pc + 32'd4);

         // ---- IMem Rd: address and enable ----
         $imem_rd_addr[(M4_IMEM_INDEX_CNT-1):0] = $pc[(M4_IMEM_INDEX_CNT+1):2];
         $imem_rd_en = ! $reset;
      @1
         // ---- IMem Rd: data. Fetch nothing (all zeros) during reset. ----
         $instr[31:0] = $imem_rd_en ? $imem_rd_data[31:0] : 32'b0;

         // ---- Dec: instruction type ----
         $is_i_instr = ($instr[6:2] ==? 5'b0000x) || ($instr[6:2] ==? 5'b001x0) || ($instr[6:2] ==? 5'b11001) || ($instr[6:2] ==? 5'b11100);
         $is_r_instr = ($instr[6:2] ==? 5'b01011) || ($instr[6:2] ==? 5'b011x0) || ($instr[6:2] ==? 5'b10100);
         $is_s_instr = ($instr[6:2] ==? 5'b0100x);
         $is_b_instr = ($instr[6:2] ==? 5'b11000);
         $is_j_instr = ($instr[6:2] ==? 5'b11011);
         $is_u_instr = ($instr[6:2] ==? 5'b0x101);

         // ---- Dec: immediate ----
         $imm[31:0] = $is_i_instr ? {{21{$instr[31]}}, $instr[30:20]} :
                      $is_s_instr ? {{21{$instr[31]}}, $instr[30:25], $instr[11:7]} :
                      $is_b_instr ? {{20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0} :
                      $is_u_instr ? {$instr[31:12], 12'b0} :
                      $is_j_instr ? {{12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0} :
                                    32'b0;

         // ---- Dec: instruction fields, each only meaningful for the types that have it ----
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

         // ---- Dec: specific instructions ----
         $dec_bits[10:0] = {$funct7[5], $funct3, $opcode};
         $is_beq  = $dec_bits ==? 11'bx_000_1100011;
         $is_bne  = $dec_bits ==? 11'bx_001_1100011;
         $is_blt  = $dec_bits ==? 11'bx_100_1100011;
         $is_bge  = $dec_bits ==? 11'bx_101_1100011;
         $is_bltu = $dec_bits ==? 11'bx_110_1100011;
         $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
         $is_addi = $dec_bits ==? 11'bx_000_0010011;
         $is_add  = $dec_bits ==? 11'b0_000_0110011;
         $is_jal  = $is_j_instr;

         // ---- Error detection: instruction ----
         // Anything outside the supported set is illegal. (All-zero instructions
         // during reset are not errors.) An illegal instruction never writes the RF.
         $is_supported = $is_add || $is_addi || $is_beq || $is_bne || $is_blt ||
                         $is_bge || $is_bltu || $is_bgeu || $is_jal;
         $illegal_instr = ! $reset && ! $is_supported;

         // ---- RF Rd: read requests (the RF macro reads >>1$value of the addressed register) ----
         $rf_rd_en1 = $rs1_valid;
         $rf_rd_index1[4:0] = $rs1;
         $rf_rd_en2 = $rs2_valid;
         $rf_rd_index2[4:0] = $rs2;
         $src1_value[31:0] = $rf_rd_data1;
         $src2_value[31:0] = $rf_rd_data2;

         // ---- ALU ----
         // JAL writes its link address (PC + 4). Unsupported instructions give 0
         // (rather than an unknown value) and are blocked from writing below.
         $result[31:0] = $is_jal  ? ($pc + 32'd4) :
                         $is_addi ? ($src1_value + $imm) :
                         $is_add  ? ($src1_value + $src2_value) :
                                    32'b0;

         // ---- RF Wr: never write x0, never write for illegal instructions ----
         $rf_wr_en = $rd_valid && ($rd != 5'b00000) && ! $illegal_instr;
         $rf_wr_index[4:0] = $rd;
         $rf_wr_data[31:0] = $rf_wr_en ? $result : 32'd0;

         // ---- Branch / jump decision ----
         // Signed compares use the sign-difference trick; unsigned ones compare directly.
         $taken_br = (! $is_b_instr) ? 1'b0 :
                     $is_beq  ? ($src1_value == $src2_value) :
                     $is_bne  ? ($src1_value != $src2_value) :
                     $is_blt  ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
                     $is_bge  ? (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
                     $is_bltu ? ($src1_value < $src2_value) :
                     $is_bgeu ? ($src1_value >= $src2_value) :
                                1'b0;
         $pc_redirect = $taken_br || $is_jal;
         // Branch and JAL targets are both PC + immediate.
         $br_tgt_pc[31:0] = $pc + $imm;

         // ---- Error detection: control flow ----
         // Target must be 4-byte aligned (no compressed instructions).
         $misaligned_tgt = $pc_redirect && ($br_tgt_pc[1:0] != 2'b00);
         // PC has run past the last instruction (the instruction memory would silently wrap).
         $pc_out_of_range = ! $reset && ($pc[31:2] >= M4_NUM_INSTRS);

         // ---- OR-aggregation of all error conditions into one signal ----
         $error = $illegal_instr || $misaligned_tgt || $pc_out_of_range;

      // Note: Because of the magic we are using for visualisation, if visualisation is enabled below,
      //       be sure to avoid having unassigned signals (which you might be using for random inputs)
      //       other than those specifically expected in the labs. You'll get strange errors for these.

   // Assert these to end simulation (before Makerchip cycle limit).
   // Pass when the final sum is in r10 (read 5 cycles later, once it has settled).
   // Fail if any error condition was raised.
   *passed = |cpu/xreg[10]>>5$value == (1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9);
   *failed = |cpu>>5$error;

   // Macro instantiations for:
   //  o instruction memory
   //  o register file
   //  o data memory
   //  o CPU visualization
   |cpu
      m4+imem(@1)    // Args: (read stage)
      m4+rf(@1, @1)  // Args: (read stage, write stage) - if equal, no register bypass is required
      //m4+dmem(@4)    // Args: (read/write stage)

   m4+cpu_viz(@4)    // For visualisation, argument should be at least equal to the last stage of CPU logic. @4 would work for all labs.
\SV
   endmodule
