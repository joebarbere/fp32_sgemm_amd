@echo off
set HIP_PLATFORM=amd
set TMP_DIR=%cd%\tmp
set KERNEL5_ISA_DIR=%TMP_DIR%\kernel5_isa
set DEVICE_CODE_DIR=%TMP_DIR%\device_code
if not exist %TMP_DIR%\NUL mkdir %TMP_DIR%
if not exist %KERNEL5_ISA_DIR%\NUL mkdir %KERNEL5_ISA_DIR%
if not exist %DEVICE_CODE_DIR%\NUL mkdir %DEVICE_CODE_DIR%

del /Q .\tmp\*
del /Q .\tmp\kernel5_isa\*
del /Q .\tmp\device_code\*

echo Building Kernel0...
call hipcc -c -std=c++17 -O3 --offload-arch=gfx1102 src/kernel0_rocblas.cpp -o tmp/kernel0_rocblas.o

echo Building Kernel1...
call hipcc -c -std=c++17 -O3 --offload-arch=gfx1102 src/kernel1_naive.cpp -o tmp/kernel1_naive.o

echo Building Kernel2...
call hipcc -c -std=c++17 -O3 --offload-arch=gfx1102 src/kernel2_lds.cpp -o tmp/kernel2_lds.o

echo Building Kernel3...
call hipcc -c -std=c++17 -O3 --offload-arch=gfx1102 src/kernel3_registers.cpp -o tmp/kernel3_registers.o

echo Building Kernel4...
call hipcc -c -std=c++17 -O3 --offload-arch=gfx1102 src/kernel4_gmem_df.cpp -o tmp/kernel4_gmem_df.o

echo Building Kernel5...
call hipcc -c -std=c++17 -O3 --offload-arch=gfx1102 -mcumode src/kernel5_lds_optim.cpp -o tmp/kernel5_lds_optim.o

echo Extracting Kernel5 ISA...
call cd tmp/kernel5_isa
call hipcc --genco --offload-arch=gfx1102 ../../src/kernel5_lds_optim.cpp -mcumode --save-temps -o kernel5.hsaco
echo Rebuilding Kernel5 from ISA
call hipcc -target amdgcn-amd-amdhsa -mcpu=gfx1102 -mcumode -c kernel5_lds_optim-hip-amdgcn-amd-amdhsa-gfx1102.s -o kernel.o
call ld.lld -shared kernel.o -o kernel.hsaco
echo Sanity check...
call fc /b kernel5_lds_optim-hip-amdgcn-amd-amdhsa-gfx1102.o kernel.o
rem call fc /b kernel5.hsaco kernel.hsaco
call cd ../..

echo Building Kernel6...
call hipcc -Wunused-result -c -std=c++17 -O3 --offload-arch=gfx1102 src/kernel6_valu_optim.cpp -o tmp/kernel6_valu_optim.o

echo Building Kernel7...
call hipcc -Wunused-result -c -std=c++17 -O3 --offload-arch=gfx1102 src/kernel7_unroll.cpp -o tmp/kernel7_unroll.o

echo Building Kernel8...
call hipcc -Wunused-result -c -std=c++17 -O3 --offload-arch=gfx1102 src/kernel8_batched_gmem.cpp -o tmp/kernel8_batched_gmem.o

echo Building host code...
call hipcc -c -std=c++17 -O3 --offload-arch=gfx1102 src/main.cpp -o tmp/main.o
call hipcc -std=c++17 -O3 --offload-arch=gfx1102 -lrocblas -Wno-unused-command-line-argument tmp/*.o -o tmp/sgemm.exe

echo Building Kernel6 from ISA
echo:
call clang -target amdgcn-amd-amdhsa -mcpu=gfx1102 -c src/kernel6_valu_optim.s -o tmp/device_code/kernel6_device_code.o
call ld.lld -shared tmp/device_code/kernel6_device_code.o -o tmp/kernel6.hsaco

echo Building Kernel7 from ISA
echo:
call clang -target amdgcn-amd-amdhsa -mcpu=gfx1102 -c src/kernel7_unroll.s -o tmp/device_code/kernel7_device_code.o
call ld.lld -shared tmp/device_code/kernel7_device_code.o -o tmp/kernel7.hsaco

echo Building Kernel8 from ISA
echo:
call clang -target amdgcn-amd-amdhsa -mcpu=gfx1102 -c src/kernel8_batched_gmem.s -o tmp/device_code/kernel8_device_code.o
call ld.lld -shared tmp/device_code/kernel8_device_code.o -o tmp/kernel8.hsaco

echo Build completed successfully.