module parser(
input  wire        clk,
input  wire        resetn,

input  wire [31:0] s_axis_tdata,
input  wire [3:0]  s_axis_tkeep,
input  wire        s_axis_tvalid,
input  wire        s_axis_tlast,
output wire        s_axis_tready,

output wire [31:0] m_axis_tdata,
output wire [3:0]  m_axis_tkeep,
output wire        m_axis_tvalid,
output wire        m_axis_tlast,
input  wire        m_axis_tready,

output reg [31:0]  src_ip,
output reg         ip_valid,   
output reg         is_ipv4
);
    
localparam IDLE      = 3'd0;
localparam PARSE_ETH = 3'd1;
localparam PARSE_IP  = 3'd2;
localparam WAIT_LAST = 3'd3;

reg [2:0] current_state;
reg [7:0] word_cnt;

reg [31:0] out_data_reg;
reg [3:0]  out_keep_reg;
reg        out_last_reg;
reg        out_valid_reg;

assign s_axis_tready = m_axis_tready || !out_valid_reg;

assign m_axis_tdata  = out_data_reg;
assign m_axis_tkeep  = out_keep_reg;
assign m_axis_tlast  = out_last_reg;
assign m_axis_tvalid = out_valid_reg;

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        out_data_reg  <= 32'd0;
        out_keep_reg  <= 4'd0;
        out_last_reg  <= 1'b0;
        out_valid_reg <= 1'b0;
    end else begin
    if (s_axis_tready) begin
        out_data_reg  <= s_axis_tdata;
        out_keep_reg  <= s_axis_tkeep;
        out_last_reg  <= s_axis_tlast;
        out_valid_reg <= s_axis_tvalid;
    end
  end
end

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        current_state <= IDLE;
        word_cnt      <= 8'd0;
        src_ip        <= 32'd0;
        ip_valid      <= 1'b0;
        is_ipv4       <= 1'b0;
    end else begin
    ip_valid <= 1'b0;  
    if (s_axis_tready && s_axis_tvalid) begin 
        if (s_axis_tlast) begin
            word_cnt <= 8'd0;
        end else begin
            word_cnt <= word_cnt + 1'b1;
        end  
        
    case (current_state)
       IDLE: begin
          ip_valid <= 1'b0;
          is_ipv4  <= 1'b0;
          src_ip   <= 32'd0;
        if (s_axis_tlast)
          current_state <= IDLE;
      else
          current_state <= PARSE_ETH;
      end
        
         PARSE_ETH: begin
           if (s_axis_tlast)
                  current_state <= IDLE;
           else if (word_cnt == 8'd3) begin
               if ({s_axis_tdata[7:0], s_axis_tdata[15:8]} == 16'h0800) begin
                   is_ipv4 <= 1'b1;
                   current_state <= PARSE_IP;
           end else begin
                   is_ipv4 <= 1'b0;
                   ip_valid      <= 1'b1;
                   current_state <= WAIT_LAST;
             end
          end
       end

         PARSE_IP: begin
           if (s_axis_tlast) 
           current_state <= IDLE;
           else if (word_cnt == 8'd6) begin
               src_ip[31:16] <= {s_axis_tdata[23:16], s_axis_tdata[31:24]};
           end
           else if (word_cnt == 8'd7) begin
               src_ip[15:0]  <= {s_axis_tdata[7:0], s_axis_tdata[15:8]};
               ip_valid      <= 1'b1;
               current_state <= WAIT_LAST;
            end
         end
    
        WAIT_LAST: begin
          if (s_axis_tlast) begin
              current_state <= IDLE;
          end
        end
                    
        default: current_state <= IDLE;
                
        endcase
       end
    end
 end
endmodule
