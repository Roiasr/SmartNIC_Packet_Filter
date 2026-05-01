module Firewall(
input  wire        clk,
input  wire        resetn,

input  wire [31:0] s_axis_tdata,
input  wire [3:0]  s_axis_tkeep,
input  wire        s_axis_tvalid,
input  wire        s_axis_tlast,
output wire        s_axis_tready,

input  wire [31:0] src_ip,       
input  wire        ip_valid,      
input  wire        is_ipv4,

input  wire        crc_done,      
input  wire        crc_pass,
    
output wire        bram_en,      
output wire [9:0]  bram_addr,     
input  wire [63:0] bram_dout,

output wire [31:0] m_axis_tdata,
output wire [3:0]  m_axis_tkeep,
output wire        m_axis_tvalid, 
output wire        m_axis_tlast,
input  wire        m_axis_tready,
output wire        m_axis_tuser
   );
   
localparam STATE_IDLE       = 3'd0; 
localparam STATE_WAIT_IP    = 3'd1; 
localparam STATE_CHECK_BRAM = 3'd2; 
localparam STATE_PASS       = 3'd3; 
localparam STATE_DROP       = 3'd4;

parameter FIFO_DEPTH = 16;
parameter ADDR_WIDTH = 4;
reg [2:0] current_state, next_state;
(* ram_style = "distributed" *)
reg [36:0] fifo_mem [0:FIFO_DEPTH - 1];

reg [ADDR_WIDTH :0]  wr_ptr;      
reg [ADDR_WIDTH :0]  rd_ptr;

reg [31:0] ip_reg;
reg pop_fifo;

assign bram_addr = {2'b00, src_ip[31:24] ^ src_ip[23:16] ^ src_ip[15:8] ^ src_ip[7:0]};

wire fifo_empty = (wr_ptr == rd_ptr);
wire fifo_full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH - 1:0] == rd_ptr[ADDR_WIDTH - 1:0]);

assign s_axis_tready = ~fifo_full;

always @(posedge clk) begin
    if (s_axis_tvalid && s_axis_tready) begin
        fifo_mem[wr_ptr[ADDR_WIDTH-1:0]] <= {s_axis_tlast, s_axis_tkeep, s_axis_tdata};
    end
end

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
        rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
        ip_reg <= 32'd0;
    end else begin
        if (s_axis_tvalid && s_axis_tready) begin
            wr_ptr <= wr_ptr + 1'b1;
        end
        
        if (pop_fifo) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
        
        if (ip_valid) begin
            ip_reg <= src_ip;
        end
    end
end

reg captured_crc_pass;
always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            captured_crc_pass <= 1'b1; 
        end else if (crc_done) begin
            captured_crc_pass <= crc_pass; 
        end
end

assign bram_en = (current_state == STATE_WAIT_IP) && ip_valid && is_ipv4;

always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
end

wire [36:0] current_fifo_word = fifo_mem[rd_ptr[3:0]];
assign m_axis_tdata = current_fifo_word[31:0];
assign m_axis_tkeep = current_fifo_word[35:32];
assign m_axis_tlast = current_fifo_word[36];

reg fsm_tvalid;
reg fsm_tuser;
assign m_axis_tvalid = fsm_tvalid;
assign m_axis_tuser  = fsm_tuser;

always @(*) begin
        next_state = current_state; 
        pop_fifo   = 1'b0;
        fsm_tvalid = 1'b0;
        fsm_tuser  = 1'b0;
        
     case (current_state)
        
     STATE_IDLE: begin
        if (!fifo_empty) begin
        next_state = STATE_WAIT_IP;
        end
     end
        
     STATE_WAIT_IP: begin   
        if (ip_valid) begin
            if (is_ipv4) begin
                next_state = STATE_CHECK_BRAM;
            end else begin
                next_state = STATE_PASS;
            end
         end 
      end
      
      STATE_CHECK_BRAM: begin
        if (bram_dout[32] && (bram_dout[31:0] == ip_reg)) begin
            next_state = STATE_DROP;
        end else begin
            next_state = STATE_PASS;
        end
       end
       
       STATE_PASS: begin
         if (!fifo_empty) begin
             fsm_tvalid = 1'b1;
           
             if (m_axis_tready) begin
                 pop_fifo   = 1'b1;
             
                 if (current_fifo_word[36]) begin
                     if (!captured_crc_pass) begin
                         fsm_tuser = 1'b1;
                     end
                     next_state = STATE_IDLE;
                 end
              end
            end
         end
         
       STATE_DROP: begin
         if (!fifo_empty) begin
             pop_fifo = 1'b1;
             if (current_fifo_word[36]) begin
                 next_state = STATE_IDLE;
             end
          end
        end
       
       default: next_state = STATE_IDLE;
    endcase
end
endmodule
