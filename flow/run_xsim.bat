@echo off
REM Run the SystemVerilog testbenches under Vivado's XSim.
REM
REM From a Command Prompt at the repo root, after running Vivado's settings64.bat
REM so that xvlog, xelab and xsim are on PATH:
REM
REM   flow\run_xsim.bat
REM
REM PowerShell will not work, because settings64.bat sets environment variables
REM that do not survive back into a PowerShell session.

xvlog -sv tb/tb_mult_approx_scoreboard.v rtl/mult_approx.v || exit /b 1
xelab -debug typical tb_mult_approx_scoreboard -s sim_sb || exit /b 1
xsim sim_sb -runall || exit /b 1
