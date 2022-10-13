#pragma once

#include "context.h"
#include "encryptionparams_cuda.cuh"
#include "utils/ntt_cuda.cuh"

namespace troy {

    class SEALContextCuda {
    public:

        class ContextDataCuda {

            friend class SEALContextCuda;
        
        public:
            ContextDataCuda() = delete;
            ContextDataCuda(const ContextDataCuda& copy) = delete;
            ContextDataCuda(ContextDataCuda&& move) = default;
            ContextDataCuda& operator=(const ContextDataCuda& copy) = delete;
            ContextDataCuda& operator=(ContextDataCuda&& move) = default;

            // Note that calling this constructor
            // sets the created to have prev-context-data and next-context-data
            // to nullptr. You need to set them up manually.
            ContextDataCuda(const SEALContext::ContextData& contextData):
                qualifiers_(contextData.qualifiers()),
                parms_(contextData.parms()),
                total_coeff_modulus_bit_count_(contextData.totalCoeffModulusBitCount()),
                plain_upper_half_threshold_(contextData.plainUpperHalfThreshold()),
                coeff_modulus_mod_plain_modulus_(contextData.coeffModulusModPlainModulus()),
                prev_context_data_(),
                next_context_data_(nullptr),
                chain_index_(contextData.chainIndex())
            {
                size_t n = contextData.small_ntt_tables_.size();
                small_ntt_tables_support_ = util::HostArray<util::NTTTablesCuda>(n);
                for (size_t i = 0; i < n; i++) {
                    small_ntt_tables_support_[i] = util::NTTTablesCuda(contextData.small_ntt_tables_[i]);
                }
                small_ntt_tables_ = util::DeviceArray(small_ntt_tables_support_);

                n = contextData.plain_ntt_tables_.size();
                plain_ntt_tables_support_ = util::HostArray<util::NTTTablesCuda>(n);
                for (size_t i = 0; i < n; i++) {
                    plain_ntt_tables_support_[i] = util::NTTTablesCuda(contextData.plain_ntt_tables_[i]);
                }
                plain_ntt_tables_ = util::DeviceArray(plain_ntt_tables_support_);
            }

            const EncryptionParametersCuda& parms() const {return parms_;}
            inline const ParmsID& parmsID() const noexcept {
                return parms_.parmsID();
            }
            inline int totalCoeffModulusBitCount() const {
                return total_coeff_modulus_bit_count_;
            }
            
            inline util::ConstDevicePointer<util::NTTTablesCuda> smallNTTTables() const {
                return small_ntt_tables_.asPointer();
            }
            
            inline util::ConstDevicePointer<util::NTTTablesCuda> plainNTTTables() const {
                return plain_ntt_tables_.asPointer();
            }


        private:

            EncryptionParametersCuda parms_;
            EncryptionParameterQualifiers qualifiers_;

            // TODO: util::HostObject<util::RNSToolCuda> rns_tool
            util::DeviceArray<util::NTTTablesCuda> small_ntt_tables_;
            util::DeviceArray<util::NTTTablesCuda> plain_ntt_tables_;
            util::HostArray<util::NTTTablesCuda> small_ntt_tables_support_;
            util::HostArray<util::NTTTablesCuda> plain_ntt_tables_support_;
            // TODO: galois_tool_
            // TODO: total_coeff_modulus_
            
            int total_coeff_modulus_bit_count_ = 0;
            
            // TODO: coeff_div_plain_modulus
            
            uint64_t plain_upper_half_threshold_ = 0;

            // TODO: plain_upper_half_increment_;
            // TODO: upper_half_threshold_
            // TODO: upper_half_increment_

            uint64_t coeff_modulus_mod_plain_modulus_ = 0;
            
            std::weak_ptr<const ContextDataCuda> prev_context_data_;

            std::shared_ptr<const ContextDataCuda> next_context_data_{ nullptr };

            std::size_t chain_index_ = 0;

        };

        SEALContextCuda(const SEALContext& context) {
            for (auto& pair: context.context_data_map_) {
                context_data_map_.emplace(std::make_pair(
                    pair.first,
                    std::make_shared<ContextDataCuda>(std::move(ContextDataCuda(*pair.second)))
                ));
            }
            // re-establish the chain
            for (auto& pair: context.context_data_map_) {
                ParmsID current_id = pair.first;
                auto prev = pair.second->prevContextData();
                if (prev) {
                    context_data_map_.at(current_id)->prev_context_data_
                        = context_data_map_.at(prev->parmsID());
                }
                auto next = pair.second->nextContextData();
                if (next) {
                    context_data_map_.at(current_id)->next_context_data_
                        = context_data_map_.at(next->parmsID());
                }
            }
            key_parms_id_ = context.keyParmsID();
            first_parms_id_ = context.firstParmsID();
            last_parms_id_ = context.lastParmsID();
        }
        
        SEALContextCuda(const SEALContextCuda& copy) = default;
        SEALContextCuda(SEALContextCuda&& move) = default;

        inline std::shared_ptr<ContextDataCuda> getContextData(ParmsID parms_id) const {
            auto data = context_data_map_.find(parms_id);
            return 
                (data != context_data_map_.end()) ?
                data->second : std::shared_ptr<ContextDataCuda>{nullptr};
        }

        inline std::shared_ptr<ContextDataCuda> firstContextData() const {
            return getContextData(first_parms_id_);
        }

        inline std::shared_ptr<ContextDataCuda> lastContextData() const {
            return getContextData(last_parms_id_);
        }

        inline std::shared_ptr<ContextDataCuda> keyContextData() const {
            return getContextData(key_parms_id_);
        }
    
    private:

        // ParmsID createNextContextData(const ParmsID &prev_parms);
        
        ParmsID key_parms_id_;
        ParmsID first_parms_id_;
        ParmsID last_parms_id_;

        std::unordered_map<ParmsID, std::shared_ptr<ContextDataCuda>, std::TroyHashParmsID> context_data_map_{};

        SecurityLevel sec_level_;
        bool using_keyswitching_;

    };

}