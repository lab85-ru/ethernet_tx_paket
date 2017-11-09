// top

`define DEBUG


module top(
    input wire i_clk,
	 
    output wire [1:0] o_eth_data,  // TX data to ETH
    output wire o_eth_tx_en        // TX enable to ETH data

	 ,
	 output wire o_led_tx           // LED En TX
`ifdef DEBUG
    ,
    output wire [31:0] d_crc32
`endif
	 
);

localparam PAKET_PAUSE = 32'd1000;

reg [31:0] delay = 0;
reg        led_tx = 0;

wire [10:0] ram_adr;
wire  [7:0] ram_data;
wire        ram_re;

reg       tx_en    = 0;
wire      tx_ready;
reg [7:0] st       = 0;

eth_tx
#(
    .PAKET_MAX_SIZE( 11'd1500 )   // maksimalnaya dlinna paketa
)
ETH_TX2
(
    .i_clk(       i_clk       ),
    .i_tx_en(     tx_en       ), // start tx
    .o_tx_ready(  tx_ready    ), // tx end, modules ready
    .o_eth_data(  o_eth_data  ), // TX data to ETH
    .o_eth_tx_en( o_eth_tx_en ), // TX enable to ETH data
    .i_ram_data(  ram_data    ), // interface for ext RAM
    .o_ram_adr(   ram_adr     ),
    .o_ram_re(    ram_re      ),
    .i_ram_data_size( 60    )  // razmer danih dla posilki to eth

`ifdef DEBUG
    ,
    .d_crc32( d_crc32)	 
`endif
	 
);



// RAM buffer, for tx paket
ram_ip_paket_tx RAM1(
	.data(        0            ),
	.rdaddress(   ram_adr      ),
	.rdclock(     i_clk        ),
	.rden(        ram_re       ),
	.wraddress(   0            ),
	.wrclock(     0            ),
	.wren(        0            ),
	.q(           ram_data     )
);


always @(posedge i_clk)
begin
    case(st)
	 0:
	 begin
	     if (tx_ready) begin
		      tx_en <= 1;
				led_tx <= 1;
				st    <= st + 1'b1;
		  end
	 end
	 
	 1:
	 begin
	     tx_en <= 0;
	     st    <= st + 1'b1;
	 end
	 
	 2:
	 begin
	     st    <= st + 1'b1;
	 end
	 
	 3:
	 begin
	     if (tx_ready) begin
				led_tx <= 0;
				st    <= st + 1'b1;
		  end
	 end

	 4:
	 begin
	     delay <= 0;
	     st    <= st + 1'b1;
	 end
	 
	 5:
	 begin
	     delay <= delay + 1'b1;
		  if (delay == PAKET_PAUSE) st <= 0;
	 end
	 
	 
	 
	 default: st <= 0;
	 
	 endcase
end

assign o_led_tx = led_tx;

endmodule
