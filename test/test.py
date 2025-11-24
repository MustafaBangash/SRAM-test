import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

def set_inputs(dut, enable, read_not_write, data_in):
    """Set input pins"""
    dut.ui_in.value = (enable << 5) | (read_not_write << 4) | (data_in & 0xF)

def get_outputs(dut):
    """Read output pins"""
    out = int(dut.uo_out.value)
    data_out = out & 0xF
    ready = (out >> 4) & 1
    return data_out, ready

@cocotb.test()
async def test_4bit_sram(dut):
    """Test simple 4-bit SRAM read/write"""
    
    dut._log.info("=" * 60)
    dut._log.info("4-Bit SRAM Test")
    dut._log.info("=" * 60)
    
    # Start clock
    clock = Clock(dut.clk, 20, unit="ns")  # 50MHz
    cocotb.start_soon(clock.start())
    
    # Reset
    dut._log.info("Applying reset...")
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.uio_in.value = 0
    set_inputs(dut, enable=0, read_not_write=0, data_in=0)
    
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    dut._log.info("✓ Reset complete\n")
    
    # Test data patterns
    test_patterns = [
        0xA,  # 1010
        0x5,  # 0101
        0xF,  # 1111
        0x0,  # 0000
        0x9,  # 1001
    ]
    
    # Write tests
    dut._log.info("Writing test patterns...")
    for data in test_patterns:
        dut._log.info(f"  Writing: 0x{data:X}")
        set_inputs(dut, enable=1, read_not_write=0, data_in=data)
        await ClockCycles(dut.clk, 2)
        
        # Disable
        set_inputs(dut, enable=0, read_not_write=0, data_in=0)
        await ClockCycles(dut.clk, 1)
        
        # Read back
        dut._log.info(f"  Reading back...")
        set_inputs(dut, enable=1, read_not_write=1, data_in=0)
        await ClockCycles(dut.clk, 3)  # Wait for read to complete
        
        data_out, ready = get_outputs(dut)
        dut._log.info(f"  Read: 0x{data_out:X}, Ready: {ready}")
        
        assert data_out == data, f"Data mismatch: got 0x{data_out:X}, expected 0x{data:X}"
        
        # Disable
        set_inputs(dut, enable=0, read_not_write=0, data_in=0)
        await ClockCycles(dut.clk, 1)
    
    dut._log.info("✓ All tests passed!\n")
    dut._log.info("=" * 60)
