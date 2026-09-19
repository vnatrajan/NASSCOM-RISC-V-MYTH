\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   // Macro providing required top-level module definition, random
   // stimulus support, and Verilator config.
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   // Connect SV inputs to TLV pipesignals.
   |calc
      // ---- @1: everything to the left of the first stage line in the diagram ----
      @1
         $reset = *reset;

         // (1) Recirculate the result from two cycles back (>>2).
         $val1[31:0] = >>2$out;
         $val2[31:0] = $rand2[3:0];   // random stimulus for the second operand
         $op[1:0]    = $rand3[1:0];   // random stimulus for the operation select

         // The four ALU operators, all computed in parallel.
         $sum[31:0]  = $val1 + $val2;
         $diff[31:0] = $val1 - $val2;
         $prod[31:0] = $val1 * $val2;
         $quot[31:0] = $val1 / $val2;

         // Valid toggle: adder (+1) fed back through >>1, forced to 0 by reset.
         // (2) $valid is produced here but consumed in @2, so it crosses the stage line.
         $valid = $reset ? 1'b0 : (>>1$valid + 1'b1);

      // ---- @2: mux, inverter and OR gate, between the two stage lines ----
      @2
         // (3) Invert $valid, OR with $reset; when true, force the output to 0.
         $out[31:0] = ($reset || !$valid) ? 32'b0 :
                      // 4:1 mux selected by $op: 0=+, 1=-, 2=*, 3=/
                      $op[1] ? ($op[0] ? $quot : $prod)
                             : ($op[0] ? $diff : $sum);

   // Assert these to end simulation (before the cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule
