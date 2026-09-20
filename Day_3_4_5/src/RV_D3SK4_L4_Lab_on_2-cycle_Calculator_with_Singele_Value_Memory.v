\m5_TLV_version 1d: tl-x.org
\m5
   //use(m5-1.0)   /// uncomment to use M5 macro library.
\SV
   // Macro providing required top-level module definition, random
   // stimulus support, and Verilator config.
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   // 2-cycle calculator with validity and a single-value memory.
   //
   //   $op   operation
   //   000   sum          100   RECALL (output the remembered value)
   //   001   difference   101   MEM    (remember the current value)
   //   010   product      110   illegal (output 0)
   //   011   quotient     111   illegal (output 0)
   |calc
      @1
         $reset = *reset;

         // 1-bit toggle: 0 in reset, then 1, 0, 1, 0, ...
         $valid = $reset ? 1'b0 : (>>1$valid + 1'b1);

         // Active during reset (so the pipeline settles) and on valid cycles.
         $valid_or_reset = $valid || $reset;

      ?$valid_or_reset
         @1
            // Operand 1 is the previous real result, from two cycles ago.
            // Start from zero if that cycle was a reset cycle.
            $val1[31:0] = >>2$reset ? 32'b0 : >>2$out;

            $val2[31:0] = $rand2[3:0];   // random 4-bit operand

            // Step 1: the opcode is now 3 bits wide.
            $op[2:0] = $rand3[2:0];

            $sum[31:0]  = $val1 + $val2;
            $diff[31:0] = $val1 - $val2;
            $prod[31:0] = $val1 * $val2;
            // Divide-by-zero guard: define the result as 0.
            $quot[31:0] = ($val2 == 32'b0) ? 32'b0 : ($val1 / $val2);

            // Opcode decode for the memory operations.
            $recall_op  = ($op == 3'b100);
            $mem_op     = ($op == 3'b101);
            $illegal_op = $op[2] && $op[1];      // 110 and 111 are not defined
         @2
            // Step 3: the output mux selects the recalled value for op 100.
            // MEM (101) and the illegal ops (11x) fall through to 0.
            $out[31:0] = $op[2] ? ($recall_op ? >>2$mem : 32'b0)
                                : ($op[1] ? ($op[0] ? $quot : $prod)
                                          : ($op[0] ? $diff : $sum));

            // Step 2: memory mux. Cleared by reset, loaded with the current
            // operand ($val1) on MEM, and otherwise holds the value it had
            // on the previous valid cycle (two cycles back).
            $mem[31:0] = $reset ? 32'b0 : ($mem_op ? $val1 : >>2$mem);

   // Assert these to end simulation (before the cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule
