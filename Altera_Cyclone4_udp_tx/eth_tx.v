//=============================================================================
// ethernet tx module
//=============================================================================

`define DEBUG

module eth_tx
#(
    parameter PAKET_MAX_SIZE = 11'd1500        // maksimalnaya dlinna paketa
)
(
    input wire i_clk,

	 input wire i_tx_en,               // start tx
	 output wire o_tx_ready,           // tx end, modules ready
	 
	 
    output wire [1:0] o_eth_data,     // TX data to ETH
	 output wire o_eth_tx_en,          // TX enable to ETH data
	 
    input wire [7:0] i_ram_data,      // interface for ext RAM
	 output wire [10:0] o_ram_adr,
	 output wire o_ram_re,
	 
	 input wire [10:0] i_ram_data_size // razmer danih dla posilki to eth
`ifdef DEBUG
    ,
	 output wire [31:0] d_crc32
`endif	 
);

reg [1:0] eth_data  = 0;
reg       eth_tx_en = 0;

reg [10:0] ram_adr = 0;
reg        ram_re  = 0;

reg tx_ready = 1;

reg [4:0] preable_count = 0; // count - for 55 55 55 55 55 55 55
localparam PREAMBLE_0x5_SIZE = 5'd28; // 1(0x5) * 14 * 2(tak kak peredaem danie po 2 bita!)
localparam PREAMBLE_0x5      = 2'b01;
localparam PREAMBLE_0xD      = 2'b11;

reg [4:0] st = 0;

reg crc_en = 0;
reg crc_rst = 0;
wire [31:0] crc_out;


//=============================================================================
crc CRC_TX
(
    .data_in( {i_ram_data[0], i_ram_data[1], i_ram_data[2], i_ram_data[3], i_ram_data[4], i_ram_data[5], i_ram_data[6], i_ram_data[7]} ),
    .crc_en(   crc_en       ),
    .crc_out(  crc_out      ),
    .rst(      crc_rst      ),
    .clk(      i_clk        )
);
//=============================================================================
always @(posedge i_clk)
begin
    case(st)
	 0:
	 begin
	     if (i_tx_en && i_ram_data_size <= PAKET_MAX_SIZE) begin
		      preable_count <= 0;
		      tx_ready <= 0;
		      st       <= st + 1'b1;
		  end
	 end

	 //=========================================================================
	 // TX PREABLE 14 raz 0x5 * 2 y.k. peredaem po 2 bita
	 1:
	 begin
	     eth_data      <= PREAMBLE_0x5;
		  eth_tx_en     <= 1;
		  preable_count <= preable_count  + 1'b1;
		  if (preable_count == PREAMBLE_0x5_SIZE - 1) st <= st + 1'b1;
	 end

	 2:
	 begin
	     crc_rst  <= 1;              // crc - reset
	     eth_data <= PREAMBLE_0x5;
        st       <= st + 1'b1;
	 end

	 3:
	 begin
	     crc_rst  <= 0;
	     eth_data <= PREAMBLE_0x5;
	     ram_adr <= 0;
        ram_re  <= 1;
        st      <= st + 1'b1;
	 end
	 
	 4:
	 begin
	     eth_data <= PREAMBLE_0x5;
        st <= st + 1'b1;
	 end
	 
	 5:
	 begin
	     eth_data <= PREAMBLE_0xD; // razdelitel, dalhe danie peredaem ------
        st <= st + 1'b1;
	 end
	 
	 // --------------------------------------------------------------
	 6:
	 begin
        // synopsys translate_off 
        $display("RAM READ 0x%X[ 0x%X ]", ram_adr, i_ram_data);
        // synopsys translate_on
		  
		  crc_en    <= 1;                  // calcul crc

	     eth_data  <= i_ram_data[1:0];
		  eth_tx_en <= 1;
        st        <= st + 1'b1;
	 end
	 
	 7:
	 begin
	     crc_en   <= 0;
	     eth_data <= i_ram_data[3:2];
		  ram_adr  <= ram_adr + 1'b1;        // RAM adr ++
        st       <= st + 1'b1;
	 end
	 
	 8:
	 begin
        // synopsys translate_off 
        $display("Calcul CRC = 0x%x", crc_out);
        // synopsys translate_on

	     eth_data <= i_ram_data[5:4];
        st       <= st + 1'b1;
	 end
	 
	 9:
	 begin
	     eth_data <= i_ram_data[7:6];

		  if (ram_adr == i_ram_data_size) begin
                                ram_re <= 0;
				st     <= st + 1'b1;		  
		  end else begin
		      st     <= 6;		
		  end
	 end
	 
	 10:
	 begin
        // synopsys translate_off 
        $display("tx byte1 CRC = 0x%x", ~{crc_out[24],crc_out[25],crc_out[26],crc_out[27],crc_out[28],crc_out[29],crc_out[30],crc_out[31]});
		  $display("tx byte2 CRC = 0x%x", ~{crc_out[16],crc_out[17],crc_out[18],crc_out[19],crc_out[20],crc_out[21],crc_out[22],crc_out[23]});
		  $display("tx byte3 CRC = 0x%x", ~{crc_out[ 8],crc_out[ 9],crc_out[10],crc_out[11],crc_out[12],crc_out[13],crc_out[14],crc_out[15]});
		  $display("tx byte4 CRC = 0x%x", ~{crc_out[ 0],crc_out[ 1],crc_out[ 2],crc_out[ 3],crc_out[ 4],crc_out[ 5],crc_out[ 6],crc_out[ 7]});
        // synopsys translate_on
	 
	     eth_data <= ~{crc_out[30],crc_out[31]};
	     st       <= st + 1'b1;
	 end
	 
	 11:
	 begin
	     eth_data <= ~{crc_out[28],crc_out[29]};
	     st       <= st + 1'b1;
	 end
	 
	 12:
	 begin
	     eth_data <= ~{crc_out[26],crc_out[27]};
	     st       <= st + 1'b1;
	 end
	 
	 13:
	 begin
	     eth_data <= ~{crc_out[24],crc_out[25]};
	     st       <= st + 1'b1;
	 end
	 
	 14:
	 begin
	     eth_data <= ~{crc_out[22],crc_out[23]};
	     st       <= st + 1'b1;
	 end
	 
	 15:
	 begin
	     eth_data <= ~{crc_out[20],crc_out[21]};
	     st       <= st + 1'b1;
	 end
	 
	 16:
	 begin
	     eth_data <= ~{crc_out[18],crc_out[19]};
	     st       <= st + 1'b1;
	 end
	 
	 17:
	 begin
	     eth_data <= ~{crc_out[16],crc_out[17]};
	     st       <= st + 1'b1;
	 end
	 
	 18:
	 begin
	     eth_data <= ~{crc_out[14],crc_out[15]};
	     st       <= st + 1'b1;
	 end
	 
	 19:
	 begin
	     eth_data <= ~{crc_out[12],crc_out[13]};
	     st       <= st + 1'b1;
	 end
	 
	 20:
	 begin
	     eth_data <= ~{crc_out[10],crc_out[11]};
	     st       <= st + 1'b1;
	 end
	 
	 21:
	 begin
	     eth_data <= ~{crc_out[8],crc_out[9]};
	     st       <= st + 1'b1;
	 end
	 
	 22:
	 begin
	     eth_data <= ~{crc_out[6],crc_out[7]};
	     st       <= st + 1'b1;
	 end
	 
	 23:
	 begin
	     eth_data <= ~{crc_out[4],crc_out[5]};
	     st       <= st + 1'b1;
	 end
	 
	 24:
	 begin
	     eth_data <= ~{crc_out[2],crc_out[3]};
	     st       <= st + 1'b1;
	 end
	 
	 25:
	 begin
	     eth_data  <= ~{crc_out[0],crc_out[1]};
	     st       <= st + 1'b1;
	 end
	 
	 26:
	 begin
        tx_ready  <= 1;
        eth_tx_en <= 0;
        st        <= 0;		
	 end
	 
		 
	 default: st <= 0;
	 
	 endcase
end

assign o_eth_data  = eth_data;
assign o_ram_adr   = ram_adr;
assign o_eth_tx_en = eth_tx_en;
assign o_tx_ready  = tx_ready;
assign o_ram_re    = ram_re;

`ifdef DEBUG
assign d_crc32 = crc_out;
`endif

endmodule
