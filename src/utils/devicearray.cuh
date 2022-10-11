#pragma once


#include "hostarray.h"
#include "../kernelprovider.cuh"
#include <vector>
#include <exception>

namespace troy { namespace util {

template <typename T> class DevicePointer;
template <typename T> class DeviceArray;

template <typename T>
class ConstDevicePointer {
    const T* ptr;
public:
    ConstDevicePointer(): ptr(nullptr) {}
    ConstDevicePointer(const T* ptr): ptr(ptr) {}
    ConstDevicePointer(const DevicePointer<T>& d): ptr(d.get()) {}
    bool isNull() {return ptr == nullptr;}
    operator bool() const {
        return !isNull();
    }
    const T* get() const {return ptr;}
    ConstDevicePointer<T> operator+(size_t d) {
        return ConstDevicePointer(ptr+d);
    }
};

template <typename T>
class DevicePointer {
    friend class DeviceArray<T>;
    T* ptr;
    DevicePointer(T* ptr): ptr(ptr) {}
public:
    explicit DevicePointer(const DeviceArray<T>& r): ptr(r.get()) {}
    DevicePointer() {
        ptr = nullptr;
    }
    bool isNull() {return ptr == nullptr;}
    operator bool() const {
        return !isNull();
    }
    const T* get() const {return ptr;}
    T* get() {return ptr;}
    DevicePointer<T> operator +(size_t d) {return DevicePointer(ptr+d);}
    DevicePointer<T>& operator +=(size_t d) {
        ptr += d;
        return *this;
    }
};

template <typename T> 
class DeviceObject {
    T* ptr;
public:
    DeviceObject(T* p): ptr(p) {}
    DeviceObject(): ptr(nullptr) {}
    DeviceObject(const DeviceObject<T>& copy) = delete;
    DeviceObject(DeviceObject&& move) {
        ptr = move.ptr; move.ptr = nullptr;
    }
    DeviceObject& operator=(const DeviceObject& copy) = delete;
    DeviceObject& operator=(DeviceObject&& move) {
        if (ptr) KernelProvider::free(ptr);
        ptr = move.ptr; move.ptr = nullptr;
        return *this;
    }
    bool isNull() {return ptr == nullptr;}
    operator bool() const {
        return !isNull();
    }
    ~DeviceObject() {
        if (ptr) KernelProvider::free(ptr);
    }
    const T* get() {return ptr;}
    T* get() const {return ptr;}
    DeviceObject(const HostObject<T>& hostobject) {
        ptr = KernelProvider::malloc<T>(1);
        KernelProvider::copy(ptr, hostobject.get(), sizeof(T));
    }
    HostObject<T> toHost() {
        auto r = malloc(sizeof(T));
        KernelProvider::retrieve(r, ptr, 1);
        return HostObject<T>(r);
    }
};

template <typename T>
class DeviceArray {
    T* data; int len;
public:
    DeviceArray() {
        data = nullptr; len = 0;
    }
    DeviceArray(int cnt) {
        data = KernelProvider::malloc<T>(cnt);
        len = cnt;
    }

    size_t length() const {return len;}
    size_t size() const {return len;}

    // Directly use the given pointer.
    DeviceArray(T* data, int length):
        data(data), len(length) {}

    DeviceArray(DeviceArray&& a) {
        data = a.data; 
        len = a.len;
        a.data = nullptr; a.len = 0;
    }
    DeviceArray& operator=(DeviceArray&& a) {
        if (data) KernelProvider::free(data);
        data = a.data; 
        len = a.len;
        a.data = nullptr; a.len = 0;
        return *this;
    }

    DeviceArray(const HostArray<T>& host) {
        len = host.length();
        data = KernelProvider::malloc<T>(len);
        KernelProvider::copy<T>(data, host.get(), len);
    }

    ~DeviceArray() {
        if (data) KernelProvider::free(data);
    }

    DeviceArray& operator = (const DeviceArray& r) = delete;
    DeviceArray(const DeviceArray& r) = delete;
    DeviceArray copy() const {
        T* copied = KernelProvider::malloc<T>(len);
        KernelProvider::copyOnDevice<T>(copied, data, len);
        return DeviceArray(copied, len);
    }

    HostArray<T> toHost() {
        T* ret = new T[len];
        KernelProvider::retrieve(ret, data, len);
        return HostArray<T>(ret, len);
    }

    T* get() {return data;}
    const T* get() const {return data;}
    DevicePointer<T> asPointer() {return DevicePointer<T>(data);}
    ConstDevicePointer<T> asPointer() const {return ConstDevicePointer<T>(data);}
    DevicePointer<T> operator+(size_t d) {
        return DevicePointer(data + d);
    }

};

template <typename T>
class DeviceDynamicArray {

    DeviceArray<T> internal;
    size_t size_;

    void move(size_t newCapacity) {
        if (newCapacity == internal.size()) return;
        DeviceArray<T> n(newCapacity);
        if (newCapacity < size_) size_ = newCapacity;
        KernelProvider::copyOnDevice(n.get(), internal.get(), size_);
        if (newCapacity > size_)
            KernelProvider::memsetZero(n.get() + size_, newCapacity - size_);
        internal = std::move(n);
    }

public:

    DeviceDynamicArray(): internal(), size_(0) {}
    DeviceDynamicArray(size_t len): internal(len), size_(len) {}
    DeviceDynamicArray(size_t capacity, size_t size): internal(capacity), size_(size) {}
    DeviceDynamicArray(DeviceArray<T>&& move, size_t size): 
        internal(std::move(move)), size_(size) {}

    DeviceDynamicArray<T> copy() const {
        return DeviceDynamicArray(internal.copy(), size_);
    }

    DeviceDynamicArray(DeviceArray<T>&& move) {
        size_ = move.size();
        internal = std::move(move);
    }
    DeviceDynamicArray(DeviceDynamicArray<T>&& move) {
        size_ = move.size();
        internal = std::move(move.internal);
    }
    
    DeviceDynamicArray(const DeviceDynamicArray<T>& copy) {
        size_ = copy.size();
        internal = std::move(copy.internal.copy());
    }

    DeviceDynamicArray(const HostDynamicArray<T>& h):
        size_(h.size()),
        internal(h.internal) {}

    DeviceDynamicArray& operator = (const DeviceDynamicArray& copy) {
        size_ = copy.size();
        internal = std::move(copy.internal.copy());
        return *this;
    }
    DeviceDynamicArray& operator = (DeviceArray<T>&& move) {
        size_ = move.size();
        internal = std::move(move);
        return *this;
    } 
    DeviceDynamicArray& operator = (DeviceDynamicArray<T>&& move) {
        size_ = move.size();
        internal = std::move(move.internal);
        return *this;
    }
    
    size_t size() const {return size_;}
    size_t capacity() const {return internal.size();}

    void reserve(size_t newCapacity) {
        if (capacity() >= newCapacity) return;
        move(newCapacity);
    }

    void shrinkToFit() {
        if (capacity() == size_) return;
        move(size_);
    }

    void release() {
        internal = std::move(DeviceArray<T>());
        size_ = 0;
    }

    void resize(size_t newSize) {
        if (newSize > capacity()) move(newSize);
        size_ = newSize;
    }

    T* get() {return internal.get();}
    DevicePointer<T> asPointer() {return internal.asPointer();}
    ConstDevicePointer<T> asPointer() const {
        return internal.asPointer();
    }
    const T* get() const {return internal.get();}

    inline std::size_t maxSize() const noexcept {
        return (std::numeric_limits<std::size_t>::max)();
    }

    HostDynamicArray<T> toHost() {
        return HostDynamicArray<T>(std::move(internal.toHost()));
    }
    
};


}}