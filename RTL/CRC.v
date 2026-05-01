module CRC(
input  wire        clk,
input  wire        resetn,

input  wire [31:0] s_axis_tdata,  
input  wire [3:0]  s_axis_tkeep,  
input  wire        s_axis_tvalid, 
input  wire        s_axis_tready,
input  wire        s_axis_tlast,

output reg         crc_done,      
output reg         crc_pass
);

function [31:0] calc_next_crc;
input [31:0] current_crc;
input [31:0] data;
input [3:0]  keep;
        
reg [31:0] crc;
reg        fb; 
integer    byte_idx, bit_idx;
begin
crc = current_crc;
            for (byte_idx = 0; byte_idx < 4; byte_idx = byte_idx + 1) begin
                if (keep[byte_idx]) begin
                    for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                        fb = crc[0] ^ data[(byte_idx * 8) + bit_idx];
                        if (fb) begin
                            crc = (crc >> 1) ^ 32'hEDB88320; 
                        end else begin
                            crc = (crc >> 1);
                        end
                    end
                end
            end
            calc_next_crc = crc; 
        end
    endfunction

reg  [31:0] crc_reg;  
wire [31:0] next_crc;

assign next_crc = calc_next_crc(crc_reg, s_axis_tdata, s_axis_tkeep);
    
always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            crc_reg  <= 32'hFFFFFFFF; 
            crc_done <= 1'b0;
            crc_pass <= 1'b0;
        end else begin
            crc_done <= 1'b0; 
            crc_pass <= 1'b0;

            if (s_axis_tvalid && s_axis_tready) begin
                if (s_axis_tlast) begin
                    crc_done <= 1'b1; 
                    if (next_crc == 32'hDEBB20E3) 
                        crc_pass <= 1'b1; 
                        crc_reg <= 32'hFFFFFFFF; 
                    
                end else begin
                    crc_reg <= next_crc; 
                end
            end
        end
    end
endmodule
