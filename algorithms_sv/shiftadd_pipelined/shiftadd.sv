module shiftadd_pipelined (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]             x_i,       // Input
  input  logic [DATA_LENGTH-1:0]             m_i,       // Modulus
  input  logic [DATA_LENGTH-1:0]             m_bl_i,
  output logic [DATA_LENGTH-1:0]             result_o,
  output logic                    valid_o    // Result valid flag
);

localparam NUM_CHUNKS = 3;
localparam DATA_LENGTH = 64;
localparam CHUNK_LENGTH = 32;

typedef enum logic[2:0] {LOAD, COMP_BLOCK, REDUCE, ADJUST, FINISH} state_t;
state_t curr_state, next_state;

// logic [1:0]  hi_index;
logic d_finish;
logic signed [DATA_LENGTH-1:0] result_p, result_n;
logic signed [DATA_LENGTH-1:0] d_mul_i [NUM_CHUNKS-1:0];
logic signed [DATA_LENGTH-1:0] d_accumulator [NUM_CHUNKS-1:0];
logic signed [DATA_LENGTH-1:0] d_result [NUM_CHUNKS-1:0];
logic signed [DATA_LENGTH-1:0] d_chunk [NUM_CHUNKS-1:0];
logic fold_sign [NUM_CHUNKS-1];

shiftreg #(
    .SHIFT(NUM_CHUNKS+1), // +1 buffer delay, +1 mul delay, +1 buffer delay
    .DATA(1)
) shift_finish (
    .clk_i(clk_i),
    .data_i(start_i),
    .data_o(d_finish)
);
// logic [CHUNK_LENGTH-1:0] higher_bits [NUM_CHUNKS-1:0];

logic [DATA_LENGTH-1:0] lo;
logic [DATA_LENGTH-1:0] mask;
logic [DATA_LENGTH-1:0] bitlength;

logic [DATA_LENGTH-1:0] msb_mask;    
logic [DATA_LENGTH-1:0] inner_mask;
logic [NUM_CHUNKS-1:0]  num_folds;
logic is_fermat;   
logic is_mersenne; 


assign msb_mask    = 1 << (m_bl_i - 1);
assign inner_mask  = ((1 << (m_bl_i - 1)) - 1) & ~1;
assign is_fermat   = ((m_i & msb_mask)==msb_mask) && ((m_i & 1)==1) && ((m_i & inner_mask) == 0);
assign is_mersenne = ((m_i ^ ((1 << m_bl_i) - 1)) == 0);
assign bitlength   = is_fermat ? (m_bl_i - 1) : m_bl_i;
assign mask = is_fermat ? ((1 << (m_bl_i-1))-1) : m_i;
// assign lo   = (x_i & ((1 << bitlength) - 1));

// logic [63:0] res;
// assign lo = (d_mul_i[0] & ((1 << bitlength) - 1));
// logic [63:0] hi;
// assign hi = d_result_wire[1];
// assign res = (d_mul_i[0] & ((1 << bitlength) - 1)) + d_result_wire[0];


generate
    for (genvar i = 0; i < NUM_CHUNKS; i++) begin
      if(i == 0)
        assign d_chunk[i] = (d_mul_i[i] & ((1 << bitlength) - 1));
      else
        assign d_chunk[i] = ((d_mul_i[i] >> ((i) * bitlength)) & mask);
    end
endgenerate

logic signed [DATA_LENGTH-1:0] tmp [NUM_CHUNKS-1:0];
generate
  for (genvar i = 0; i < NUM_CHUNKS; i++) begin
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (i == 0) begin
          d_accumulator[i] <= d_chunk[i];
        end
        else begin
          if(is_mersenne) begin
            d_accumulator[i] <= d_accumulator[i-1] + d_chunk[i];
          end
          else begin
            d_accumulator[i] <= d_accumulator[i-1] + (fold_sign[i-1] ? -d_chunk[i] : d_chunk[i]);
          end
        end
      end
  end
endgenerate

// generate
//   for (genvar i = 0; i < NUM_CHUNKS; i++) begin
//     // Stage 1: Compute tmp[i]
//     always_ff @(posedge clk_i) begin
//       if (i == 0) begin
//         d_accumulator[i] <= tmp[i];
//       end else begin
//         if(is_mersenne) begin
//             d_accumulator[i] <= tmp[i];
//           end
//           else if (is_fermat && $signed(tmp[i]) < 0) begin
//             d_accumulator[i] <= tmp[i] + $signed(m_i);
//           end
//         // d_accumulator[i] <= d_accumulator[i-1] + (fold_sign[i-1] ? -d_chunk[i] : d_chunk[i]);
//       end
//     end
//   end
// endgenerate

// generate
//   for (genvar i = 0; i < NUM_CHUNKS; i++) begin
//     // Stage 2: Normalize tmp[i] into d_accumulator[i]
//     always_ff @(posedge clk_i or negedge rst_ni) begin
//       if (is_fermat && $signed(tmp[i]) < 0) begin
//         d_accumulator[i] <= tmp[i] + $signed(m_i);
//       end else begin
//         d_accumulator[i] <= tmp[i];
//       end
//     end
//   end
// endgenerate

generate
  for (genvar i = 0; i < NUM_CHUNKS; i++) begin
    always_ff @(posedge clk_i) begin
      if(i==0) begin
        fold_sign[i] <= 1;
      end
      else if (is_fermat) begin
        fold_sign[i] <= ~fold_sign[i-1];
      end
      else begin
        fold_sign[i] <= fold_sign[i-1];
      end
    end
  end
endgenerate

// generate
//     for (genvar i = 0; i < NUM_CHUNKS; i++) begin
//         assign d_result[i] = (d_accumulator[i] >= m_i) ? d_accumulator[i] - m_i : d_accumulator[i];
//     end
// endgenerate


always_comb begin
    for (int i = 0; i < NUM_CHUNKS; i++) begin
      // if(curr_state == FINISH) begin
        if (d_accumulator[i] >= m_i) begin
          d_result[i] = d_accumulator[i] - m_i;
        end
        else if (d_accumulator[i] < 0) begin
          d_result[i] = d_accumulator[i] + m_i;
        end
      // end
        else begin
          d_result[i] = d_accumulator[i];
        end
    end
end

always_comb begin
  next_state = curr_state;
  case (curr_state)
      LOAD : begin
        if (start_i) begin
            next_state = REDUCE;
        end
      end
      REDUCE : begin
        if(d_finish) begin
          next_state = FINISH;
        end
      end
      FINISH : begin
        next_state = FINISH;
      end
      default : begin
        next_state = LOAD;
      end
  endcase
end

assign valid_o  = d_finish;
assign result_o = d_result[NUM_CHUNKS-1];

// logic adjust_cycle_done;
// logic adjust_done;
// assign adjust_done = adjust_cycle_done;
// always_ff @(posedge clk_i or negedge rst_ni) begin
//   if (!rst_ni || ctrl_update_operands) begin
//     adjust_cycle_done <= 1'b0;
//   end else if (ctrl_adjust_result) begin
//     adjust_cycle_done <= 1'b1;  // done after one cycle in ADJUST
//   end else begin
//     adjust_cycle_done <= 1'b0;
//   end
// end


// always_ff @(posedge clk_i) begin
//   if(!rst_ni || ctrl_update_operands) begin
//     result_n <= 64'b0;
//   end
//   else if (ctrl_adjust_result) begin
//     if(result_p >= m_i) begin
//       result_n <= result_p - m_i;
//     end 
//     else if($signed(result_p) < 0) begin
//       result_n <= result_p + m_i;
//     end
//     else begin
//       result_n <= result_p;
//     end
//   end else begin
//     result_n <= 64'b0;
//   end
// end

// always_comb begin
//     if (is_fermat && $signed(result_p) < 0) begin
//         result_p = result_p + $signed(m_i);
//     end
// end

// generate
//   for (genvar i=0; i<NUM_CHUNKS; i++) begin
//     always_ff @(posedge clk_i) begin
//       $display("Cycle: %d, State: %s, start_i: %d, d_mul_i: %h",
//               $time, curr_state.name(), start_i, d_mul_i[i]);
//       end
//   end
// endgenerate

// always_ff @(posedge clk_i) begin
//     $display("Cycle: %d, State: %s, start_i: %d",
//             $time, curr_state.name(), start_i);
// end

generate
  for (genvar i=0; i<NUM_CHUNKS; i++) begin
    always_ff @(posedge clk_i) begin
      if (i == 0) begin
        d_mul_i[i] <= x_i;
      end 
      else begin
        d_mul_i[i] <= d_mul_i[i-1];
      end
    end
  end
endgenerate

// always_ff @(posedge clk_i) begin
//     if (rst_ni == 0 || ctrl_update_operands) begin
//         hi_index <= 0;
//     end 
//     else if (ctrl_update_mul_counter) begin
//         hi_index <= (hi_index == NUM_CHUNKS - 1) ? 0 : hi_index + 1;
//     end
// end

// ================================================================
// always_ff @(posedge clk_i) begin
//   // on reset, lo is 0, and that will mess up the computation if we use this: rst_ni == 0 || ctrl_clear_regs
//     if (ctrl_update_operands || start_i) begin
//         result_p <= lo;
//     end 
//     else if (ctrl_update_result) begin
//         if (is_mersenne) begin
//             result_p <= result_p + higher_bits[hi_index];
//         end else begin
//             result_p <= result_p + (fold_sign_p ? -higher_bits[hi_index] : higher_bits[hi_index]);
//         end
//     end
// end
// ================================================================

// always_ff @(posedge clk_i) begin
//     if(!rst_ni || ctrl_update_operands) begin
//         fold_sign_p <= 1;
//     end
//     else if(ctrl_update_fold_sign) begin
//         fold_sign_p <= ~fold_sign_p;
//     end
// end

// always_ff @(posedge clk_i) begin
//     if(!rst_ni || ctrl_update_operands) begin
//         num_folds <= 0;
//     end
//     else if(ctrl_update_num_folds) begin
//         num_folds <= num_folds + 1;
//     end
// end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    curr_state  <= LOAD;
  end else begin
    curr_state  <= next_state;
  end
end

// logic [63:0] curr_bits;
// assign curr_bits = higher_bits[hi_index];

endmodule : shiftadd_pipelined
