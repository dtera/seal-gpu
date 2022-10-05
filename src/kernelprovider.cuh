#pragma once

#include <stdexcept>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

namespace troy {

class KernelProvider {

    static bool initialized;
    
public:

    static void checkInitialized() {
        if (!initialized)
            throw std::invalid_argument("KernelProvider not initialized.");
    }

    static void initialize() {
        cudaSetDevice(0);
        initialized = true;
    }

    template <typename T>
    static T* malloc(int length) {
        checkInitialized();
        T* ret;
        auto status = cudaMalloc((void**)&ret, length * sizeof(T));
        if (status != cudaSuccess) 
            throw std::runtime_error("Cuda Malloc failed.");
        return ret;
    }

    template <typename T> 
    static void free(T* pointer) {
        checkInitialized();
        cudaFree(pointer);
    }

    template <typename T>
    static void copy(T* deviceDestPtr, const T* hostFromPtr, int length) {
        checkInitialized();
        auto status = cudaMemcpy(deviceDestPtr, hostFromPtr, length * sizeof(T), cudaMemcpyHostToDevice);
        if (status != cudaSuccess) 
            throw std::runtime_error("Cuda copy from host to device failed.");
    }

    template <typename T>
    static void copyOnDevice(T* deviceDestPtr, T* deviceFromPtr, int length) {
        checkInitialized();
        auto status = cudaMemcpy(deviceDestPtr, deviceFromPtr, length * sizeof(T), cudaMemcpyDeviceToDevice);
        if (status != cudaSuccess) 
            throw std::runtime_error("Cuda copy on device failed.");
    }

    template <typename T>
    static void retrieve(T* hostDestPtr, T* deviceFromPtr, int length) {
        checkInitialized();
        auto status = cudaMemcpy(hostDestPtr, deviceFromPtr, length * sizeof(T), cudaMemcpyDeviceToHost);
        if (status != cudaSuccess) 
            throw std::runtime_error("Cuda retrieve from device to host failed.");
    }

};

}