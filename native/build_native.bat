call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
cmake -B build -S . -G "Ninja" -DCMAKE_BUILD_TYPE=Release
if %errorlevel% neq 0 exit /b %errorlevel%
cmake --build build --config Release --target syspie_native
if %errorlevel% neq 0 exit /b %errorlevel%
cmake --build build --config Release --target syspie_native_dll
