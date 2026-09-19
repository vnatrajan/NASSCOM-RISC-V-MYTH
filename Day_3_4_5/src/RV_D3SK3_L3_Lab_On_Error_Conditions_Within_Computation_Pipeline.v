\m5_TLV_version 1d: tl-x.org
\m5
   //use(m5-1.0)   /// uncomment to use M5 macro library.
\SV
   // Macro providing required top-level module definition, random
   // stimulus support, and Verilator config.
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   // Error aggregation across a computation pipeline.
   // Each stage that can detect an error ORs its own condition into the
   // running error signal it received from the previous detecting stage.
   |comp
      @1
         $reset = *reset;

         // Error conditions detected in @1. Each is a rare random event so the
         // aggregation is visible in simulation. Qualified by !$reset so that
         // nothing is flagged while the design is still being reset.
         $bad_input  = ! $reset && ($rand_bad_input[2:0]  == 3'd0);
         $illegal_op = ! $reset && ($rand_illegal_op[2:0] == 3'd0);

         // First OR-aggregation.
         $err1 = $illegal_op || $bad_input;

      // @2: nothing is written here. $err1 passes through this stage
      //     automatically, since TL-V inserts the flop.

      @3
         // Error condition detected in @3.
         $over_flow = ! $reset && ($rand_over_flow[2:0] == 3'd0);

         // $err1 was assigned in @1 and is used here, two stages later, so TL-V
         // pipelines it through two flops. No manual delay is needed.
         $err2 = $err1 || $over_flow;

      // @4 and @5: nothing is written here either. $err2 passes through
      //            them, so the value picked up in @6 is aligned to the same
      //            transaction as the @1 inputs.

      @6
         // Error condition detected in @6.
         $div_by_zero = ! $reset && ($rand_div_by_zero[2:0] == 3'd0);

         // Final aggregate: any error from any stage of this transaction.
         $err3 = $err2 || $div_by_zero;

   // Assert these to end simulation (before the cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule
