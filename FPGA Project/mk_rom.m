function mk_rom(data,entity_name,data_type)
% mk_rom(data, entity_name [,data_type])
%     Create a VHDL entity for a ROM implemented using one or more RAM
%     blocks.  The data_type argument is optional, and overrides the
%     automatic type detection.  Valid types are 'signed', 'unsigned' and
%     'std_logic_vector'.

	% Check number of arguments
	if (nargin~=2)&&(nargin~=3)
		error('mkrom requires two or three arguments.');
	end

	% Convert data to integer vector
	data=round(data(:));

	% Compute data properties
	data_min=min(data);
	data_max=max(data);
	data_size=numel(data);

	% Handle output type
	if (nargin==2)
		% Assign output type based on data range
		if (data_min<0)
			data_type='signed';
		else
			data_type='unsigned';
		end
	else
		% Check for valid output type
		if (strcmp(data_type,'signed')==0)&&...
			(strcmp(data_type,'unsigned')==0)&&...
			(strcmp(data_type,'std_logic_vector')==0)
			error('Invalid data type.');
		end
	end

	% Block RAM geometry is based on the data range
	%
	% The block geometry can be one of:
	% 4096 9-bit words
	% 2048 18-bit words
	% 1024 36-bit words
	if (strcmp(data_type,'signed')==1)
		if (data_min>=-256)&&(data_max<=255)
			data_bits=8;
			parity_bits=1;
			block_size=4096;
			block_bits=12;
		elseif (data_min>=-131072)&&(data_max<=131071)
			data_bits=16;
			parity_bits=2;
			block_size=2048;
			block_bits=11;
		elseif (data_min>=-34359738368)&&(data_max<=34359738367)
			data_bits=32;
			parity_bits=4;
			block_size=1024;
			block_bits=10;
		else
			error('Data does not fit in a 36-bit signed integer.');
		end
	else
		if (data_min>=0)&&(data_max<=511)
			data_bits=8;
			parity_bits=1;
			block_size=4096;
			block_bits=12;
		elseif (data_min>=0)&&(data_max<=262143)
			data_bits=16;
			parity_bits=2;
			block_size=2048;
			block_bits=11;
		elseif (data_min>=0)&&(data_max<=68719476735)
			data_bits=32;
			parity_bits=4;
			block_size=1024;
			block_bits=10;
		else
			error('Data does not fit in a 36-bit unsigned integer.');
		end
	end

	% Convert to unsigned integers so Matlab's dec2hex will work
	if (data_bits+parity_bits==9)
		rr=find(data<0);
		data(rr)=data(rr)+512;
	elseif (data_bits+parity_bits==18)
		rr=find(data<0);
		data(rr)=data(rr)+262144;
	else
		rr=find(data<0);
		data(rr)=data(rr)+68719476736;
	end

	% Compute number of blocks needed
	block_count=ceil(data_size/block_size);
	if (block_count>45)
		error('Capacity exceeded -- XC7S25 only has 45 Block RAM modules.');
	end

	% Pad data to fill blocks
	data(end+1:block_count*block_size)=0;

	% Compute number of bits in the addresses
	addr_bits=ceil(log2(length(data)));

	% Open output file
	fid=fopen([entity_name '.vhd'],'w');

	% Preamble
	fprintf(fid,'library IEEE;\r\n');
	fprintf(fid,'use IEEE.std_logic_1164.all;\r\n');
	fprintf(fid,'use IEEE.numeric_std.all;\r\n');
	fprintf(fid,'library UNISIM;\r\n');
	fprintf(fid,'use UNISIM.vcomponents.all;\r\n');
	fprintf(fid,'\r\n');

	% Entity declaration
	fprintf(fid,'entity %s is\r\n',entity_name);
	fprintf(fid,'\tport(\r\n');
	fprintf(fid,'\t\tclk:  in  std_logic;\r\n');
	fprintf(fid,'\t\taddr: in  std_logic_vector');
	fprintf(fid,'(%d downto 0);\r\n',addr_bits-1);
	fprintf(fid,'\t\tdata: out %s',data_type);
	fprintf(fid,'(%d downto 0)\r\n',data_bits+parity_bits-1);
	fprintf(fid,'\t);\r\n');
	fprintf(fid,'end %s;\r\n',entity_name);
	fprintf(fid,'\r\n');

	% Start of architecture section
	fprintf(fid,'architecture arch of %s is\r\n',entity_name);

	% Signal declarations
	if (block_count~=1)
		fprintf(fid,'\tsignal addr_d:  std_logic_vector');
		fprintf(fid,'(%d downto %d);\r\n',addr_bits-1,block_bits);
	end
	fprintf(fid,'\tsignal addrardaddr:   std_logic_vector(15 downto 0);\r\n');
	for ii=0:block_count-1
		fprintf(fid,'\tsignal doado_%2.2d:  std_logic_vector',ii);
		fprintf(fid,'(31 downto 0);\r\n');
		fprintf(fid,'\tsignal dopadop_%2.2d: std_logic_vector',ii);
		fprintf(fid,'(3 downto 0);\r\n');
	end

	% Start of architecture body
	fprintf(fid,'begin\r\n');

	% Combinatorial assignments
	fprintf(fid,'\taddrardaddr(15)<=''1'';\r\n');
	fprintf(fid,'\taddrardaddr(14 downto %d)<=addr',14-block_bits+1);
	fprintf(fid,'(%d downto 0);\r\n',block_bits-1);
	if (data_bits+parity_bits==9)
		fprintf(fid,'\taddrardaddr(2 downto 0)<=b"000";\r\n');
	elseif (data_bits+parity_bits==18)
		fprintf(fid,'\taddrardaddr(3 downto 0)<=b"0000";\r\n');
	else
		fprintf(fid,'\taddrardaddr(4 downto 0)<=b"00000";\r\n');
	end

	if (block_count~=1)
		% Upper address bits delay
		fprintf(fid,'\tprocess(clk)\r\n');
		fprintf(fid,'\tbegin\r\n');
		fprintf(fid,'\t\tif (rising_edge(clk)) then\r\n');
		fprintf(fid,'\t\t\taddr_d<=addr');
		fprintf(fid,'(%d downto %d);\r\n',addr_bits-1,block_bits);
		fprintf(fid,'\t\tend if;\r\n');
		fprintf(fid,'\tend process;\r\n');

		% Block multiplexor
		fprintf(fid,'\twith addr_d select data');
		fprintf(fid,'(%d downto 0)<=\r\n',data_bits-1);
		for ii=0:block_count-2
			fprintf(fid,'\t\t%s(doado_%2.2d',data_type,ii);
			fprintf(fid,'(%d downto 0)) when ',data_bits-1);
			fprintf(fid,'b"%s",\r\n',dec2bin(ii,addr_bits-block_bits));
		end
		fprintf(fid,'\t\t%s(doado_%2.2d',data_type,block_count-1);
		fprintf(fid,'(%d downto 0)) when others;\r\n',data_bits-1);

		fprintf(fid,'\twith addr_d select data');
		fprintf(fid,'(%d downto ',data_bits+parity_bits-1);
		fprintf(fid,'%d)<=\r\n',data_bits);
		for ii=0:block_count-2
			fprintf(fid,'\t\t%s(dopadop_%2.2d',data_type,ii);
			fprintf(fid,'(%d downto 0)) when ',parity_bits-1);
			fprintf(fid,'b"%s",\r\n',dec2bin(ii,addr_bits-block_bits));
		end
		fprintf(fid,'\t\t%s(dopadop_%2.2d',data_type,block_count-1);
		fprintf(fid,'(%d downto 0)) when others;\r\n',parity_bits-1);
	else
		fprintf(fid,'\tdata(%d downto 0)<=',data_bits-1);
		fprintf(fid,'%s(doado_00',data_type);
		fprintf(fid,'(%d downto 0));\r\n',data_bits-1);
		fprintf(fid,'\tdata(%d downto ',data_bits+parity_bits-1);
		fprintf(fid,'%d)<=',data_bits);
		fprintf(fid,'%s(dopadop_00',data_type);
		fprintf(fid,'(%d downto 0));\r\n',parity_bits-1);
	end

	% Instatiate RAM blocks
	for ii=0:block_count-1
		% RAM block instantiation and start of generic section
		fprintf(fid,'\tmem_%2.2d: RAMB36E1 generic map (\r\n',ii);

		% Data bus width
		fprintf(fid,'\t\tREAD_WIDTH_A=>%d,\r\n',data_bits+parity_bits);

		% Parity initial memory contents
		for jj=0:15
			fprintf(fid,'\t\tINITP_%s=>X"',dec2hex(jj,2));
			if (data_bits+parity_bits==9)
				for kk=63:-1:0
					p1=mod(floor(data(2048*ii+256*jj+4*kk+1)/256),2);
					p2=mod(floor(data(2048*ii+256*jj+4*kk+2)/256),2);
					p3=mod(floor(data(2048*ii+256*jj+4*kk+3)/256),2);
					p4=mod(floor(data(2048*ii+256*jj+4*kk+4)/256),2);
					fprintf(fid,'%s',dec2hex(p4*8+p3*4+p2*2+p1,1));
				end
			elseif (data_bits+parity_bits==18)
				for kk=63:-1:0
					p1=mod(floor(data(1024*ii+128*jj+2*kk+1)/65536),4);
					p2=mod(floor(data(1024*ii+128*jj+2*kk+2)/65536),4);
					fprintf(fid,'%s',dec2hex(p2*4+p1,1));
				end
			else
				for kk=63:-1:0
					p1=mod(floor(data(512*ii+64*jj+kk+1)/4294967296),16);
					fprintf(fid,'%s',dec2hex(p1,1));
				end
			end
			fprintf(fid,'",\r\n');
		end

		% Data initial memory contents
		for jj=0:127
			fprintf(fid,'\t\tINIT_%s=>X"',dec2hex(jj,2));
			if (data_bits+parity_bits==9)
				for kk=31:-1:0
					d=mod(data(2048*ii+32*jj+kk+1),256);
					fprintf(fid,'%s',dec2hex(d,2));
				end
			elseif (data_bits+parity_bits==18)
				for kk=15:-1:0
					d=mod(data(1024*ii+16*jj+kk+1),65536);
					fprintf(fid,'%s',dec2hex(d,4));
				end
			else
				for kk=7:-1:0
					d=mod(data(512*ii+8*jj+kk+1),4294967296);
					fprintf(fid,'%s',dec2hex(d,8));
				end
			end
			fprintf(fid,'",\r\n');
		end

		% Simulation device type
		fprintf(fid,'\t\tSIM_DEVICE=>"7SERIES"\r\n');

		% End of generic section and start of port section
		fprintf(fid,'\t)port map(\r\n');

		% Ports
		fprintf(fid,'\t\tCASCADEOUTA=>open,\r\n');
		fprintf(fid,'\t\tCASCADEOUTB=>open,\r\n');
		fprintf(fid,'\t\tDBITERR=>open,\r\n');
		fprintf(fid,'\t\tECCPARITY=>open,\r\n');
		fprintf(fid,'\t\tRDADDRECC=>open,\r\n');
		fprintf(fid,'\t\tSBITERR=>open,\r\n');
		fprintf(fid,'\t\tDOADO=>doado_%2.2d,\r\n',ii);
		fprintf(fid,'\t\tDOPADOP=>dopadop_%2.2d,\r\n',ii);
		fprintf(fid,'\t\tDOBDO=>open,\r\n');
		fprintf(fid,'\t\tDOPBDOP=>open,\r\n');
		fprintf(fid,'\t\tCASCADEINA=>''0'',\r\n');
		fprintf(fid,'\t\tCASCADEINB=>''0'',\r\n');
		fprintf(fid,'\t\tINJECTDBITERR=>''0'',\r\n');
		fprintf(fid,'\t\tINJECTSBITERR=>''0'',\r\n');
		fprintf(fid,'\t\tADDRARDADDR=>addrardaddr,\r\n');
		fprintf(fid,'\t\tCLKARDCLK=>clk,\r\n');
		fprintf(fid,'\t\tENARDEN=>''1'',\r\n');
		fprintf(fid,'\t\tREGCEAREGCE=>''1'',\r\n');
		fprintf(fid,'\t\tRSTRAMARSTRAM=>''0'',\r\n');
		fprintf(fid,'\t\tRSTREGARSTREG=>''0'',\r\n');
		fprintf(fid,'\t\tWEA=>b"0000",\r\n');
		fprintf(fid,'\t\tDIADI=>(others=>''0''),\r\n');
		fprintf(fid,'\t\tDIPADIP=>(others=>''0''),\r\n');
		fprintf(fid,'\t\tADDRBWRADDR=>(others=>''0''),\r\n');
		fprintf(fid,'\t\tCLKBWRCLK=>''0'',\r\n');
		fprintf(fid,'\t\tENBWREN=>''0'',\r\n');
		fprintf(fid,'\t\tREGCEB=>''0'',\r\n');
		fprintf(fid,'\t\tRSTRAMB=>''0'',\r\n');
		fprintf(fid,'\t\tRSTREGB=>''0'',\r\n');
		fprintf(fid,'\t\tWEBWE=>(others=>''0''),\r\n');
		fprintf(fid,'\t\tDIBDI=>(others=>''0''),\r\n');
		fprintf(fid,'\t\tDIPBDIP=>(others=>''0'')\r\n');

		% End of port section
		fprintf(fid,'\t);\r\n');
	end

	% End of architecture section
	fprintf(fid,'end arch;\r\n');

	% Close output file
	fclose(fid);
end
