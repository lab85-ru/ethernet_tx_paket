generator_udp_packet.exe ffffffffffff 66778899aabb 192.168.12.255 192.168.12.100 10000 10000 255 udp_header.bin
bin2mif.exe -coe -datawidth 8 -i udp_header.bin -o udp_header.coe
