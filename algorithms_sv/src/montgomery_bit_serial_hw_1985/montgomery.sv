import multiplier_pkg::*;
module montgomery_serialized (
  input  logic                    CLK_pci_sys_clk_p, // Clocking wizard positive clock
  input  logic                    CLK_pci_sys_clk_n, // Clocking wizard negative clock
  input  logic                    rst_ni,
  input  logic                    start_i,
  input  logic [DATA_LENGTH-1:0]  x_i,       // Input in plain form
  input  logic [DATA_LENGTH-1:0]  y_i,       // Input in Montgomery form
  input  logic [DATA_LENGTH-1:0]  m_i,       // Modulus (e.g., 32-bit)
  input  logic [DATA_LENGTH-1:0]  m_bl_i,    // Modulus bitlength
  output logic [DATA_LENGTH-1:0]  result_o,  // Result (will be out of Montgomery form)
  output logic                    valid_o    // Result valid flag
);

typedef enum logic[2:0] {LOAD, REDUCE, FINISH} state_t;
state_t curr_state, next_state;
logic [DATA_LENGTH-1:0] mask;
logic [DATA_LENGTH-1:0] S;
logic [8:0] idx;
logic clk_i;


logic ctrl_reset_operands;
logic ctrl_update_sum;
logic ctrl_update_result;
logic ctrl_update_x_counter;
logic ctrl_start_new;

`ifdef SIMULATION
    assign clk_i = CLK_pci_sys_clk_p; // Fake the clock in simulation
`else
    clk_wiz_0 cw (
      .clk_in1_p(CLK_pci_sys_clk_p),
      .clk_in1_n(CLK_pci_sys_clk_n),
      .clk_out1(clk_i),
      .reset(~rst_ni)
    );
`endif

always_comb begin
  ctrl_reset_operands    = (curr_state == LOAD);
  ctrl_update_x_counter  = (curr_state == REDUCE);
  ctrl_update_sum        = (curr_state == REDUCE);
  ctrl_update_result     = (curr_state == FINISH);
  ctrl_start_new         = ((next_state != FINISH) && (curr_state == FINISH));
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
        if(idx == m_bl_i - 1) begin
          next_state = FINISH;
        end else begin
            next_state = REDUCE;
        end
      end
      FINISH : begin
          next_state = LOAD;
      end
      default : begin
          next_state = LOAD;
      end
  endcase
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni || ctrl_start_new)
    curr_state <= LOAD;
  else
    curr_state <= next_state;
end

always_ff @(posedge clk_i) begin
    if (rst_ni == 0 || ctrl_reset_operands) begin
        idx <= 0;
    end
    else if (ctrl_update_x_counter) begin
        idx <= idx + 1;
    end
    else begin
      idx <= idx;
    end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni || ctrl_reset_operands)
    S <= 0;
  else if(ctrl_update_sum)
    S <= montgomery_step(S, x_i[idx], y_i, m_i);
  else
    S <= S;
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    mask <= 0;
  else if (ctrl_update_result)
    mask <= {DATA_LENGTH{S >= m_i}};
  else
    mask <= mask;
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_o <= 0;
    valid_o  <= 0;
  end else begin
    result_o <= (ctrl_update_result) ? ((S & ~mask) | ((S - m_i) & mask)) : result_o;
    valid_o  <= ctrl_update_result;
  end
end


function automatic [DATA_LENGTH-1:0] montgomery_step(
    input logic [DATA_LENGTH-1:0] S,
    input logic x_b,
    input logic [DATA_LENGTH-1:0] y,
    input logic [DATA_LENGTH-1:0] modulus
  );
    logic  [DATA_LENGTH-1:0] temp1, temp2;

    // avoids branching
    temp1 = S + (y & {DATA_LENGTH{x_b}});
    temp2 = temp1 + (modulus & {DATA_LENGTH{temp1[0]}});

    return temp2 >> 1;
endfunction



endmodule:montgomery_serialized