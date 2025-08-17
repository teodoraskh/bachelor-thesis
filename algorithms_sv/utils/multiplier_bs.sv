import multiplier_pkg::*;
module multiplier_bs(
  input logic         clk_i,
  input logic         rst_ni,
  input logic         start_i,
  input logic [63:0]  indata_a_i,
  input logic [63:0]  indata_b_i,
  output logic        busy_o,
  output logic        finish_o,
  output logic [127:0] result_o
);
localparam NUM_BITS = 64;
typedef enum logic[1:0] {LOAD, MUL, FINISH} state_t;
state_t state_p, state_n;
logic [127:0] result;
logic [63:0] a_reg, b_reg;
logic [8:0] idx_reg;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_p <= LOAD;
    end else begin
      state_p <= state_n;
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      a_reg    <= 0;
      b_reg    <= 0;
    end else if (ctrl_update_operands) begin
      a_reg    <= indata_a_i;
      b_reg    <= indata_b_i;
    end else begin
      a_reg    <= a_reg;
      b_reg    <= b_reg;
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni || ctrl_update_operands) begin
        idx_reg <= 0;
    end
    else if (ctrl_update_idx) begin
        idx_reg <= (idx_reg == (NUM_BITS - 1)) ? idx_reg : idx_reg + 1;
    end
  end

  logic ctrl_update_operands;
  logic ctrl_update_result;
  logic ctrl_update_idx;

  assign ctrl_update_result   = (state_p == MUL);
  assign ctrl_update_operands = (state_p == LOAD);
  assign ctrl_update_idx      = (state_p == MUL);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni || ctrl_update_operands) begin
      result <= 0;
    end
    else if (ctrl_update_result) begin
      if(a_reg[idx_reg]) begin
         result <= result + ({64'b0, b_reg} << idx_reg);
      end else begin
        result <= result;
      end
      // result <= result + ({64'b0, b_reg} << idx_reg) & {128{a_reg[idx_reg]}};
    end else begin
      result <= result;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni || ctrl_update_operands) begin
      result_o <= 0;
      finish_o  <= 0;
    end else if (state_p == FINISH) begin
      result_o <= result;
      finish_o  <= 1;
    end else begin
      result_o <= result_o;
      finish_o  <= finish_o;
    end
  end

  always_comb begin
    state_n = state_p;
    case (state_p)
      LOAD: begin
        if(start_i) begin
          state_n = MUL;
        end
      end
      MUL: begin
        if(idx_reg == (NUM_BITS - 1)) begin
          state_n = FINISH;
        end else begin
          state_n = MUL;
        end
      end
      FINISH: begin
        state_n = LOAD;
      end
      default begin
        state_n = LOAD;
      end
    endcase
  end

endmodule: multiplier_bs
