\m5_TLV_version 1d: tl-x.org
\m5
   //use(m5-1.0)   /// uncomment to use M5 macro library.
\SV
   // Macro providing required top-level module definition, random
   // stimulus support, and Verilator config.
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   // 2-cycle calculator with validity.
   // Instead of masking $out to zero on every other cycle, the whole
   // calculation is placed under a "when" condition: it only exists (and its
   // flops only need to toggle) on cycles where $valid_or_reset is true.
   |calc
      @1
         $reset = *reset;

         // 1-bit toggle: 0 in reset, then 1, 0, 1, 0, ...
         $valid = $reset ? 1'b0 : (>>1$valid + 1'b1);

         // Active during reset (so the pipeline settles) and on valid cycles.
         $valid_or_reset = $valid || $reset;

      // Validity-aware computation: everything below is only meaningful when
      // $valid_or_reset is true. No zeroing of $out is needed.
      ?$valid_or_reset
         @1
            // Operand 1 is the previous real result, from two cycles ago.
            // If that cycle was a reset cycle there is no real result yet,
            // so start the accumulation from zero.
            $val1[31:0] = >>2$reset ? 32'b0 : >>2$out;

            $val2[31:0] = $rand2[3:0];   // random 4-bit operand
            $op[1:0]    = $rand3[1:0];   // random operation select

            $sum[31:0]  = $val1 + $val2;
            $diff[31:0] = $val1 - $val2;
            $prod[31:0] = $val1 * $val2;

            // Divide-by-zero guard: define the result as 0 rather than
            // letting the divider see a zero divisor.
            $quot[31:0] = ($val2 == 32'b0) ? 32'b0 : ($val1 / $val2);
         @2
            // 4:1 mux selected by $op: 0=+, 1=-, 2=*, 3=/
            $out[31:0] = $op[1] ? ($op[0] ? $quot : $prod)
                                : ($op[0] ? $diff : $sum);

   // Assert these to end simulation (before the cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule
