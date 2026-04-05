// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package contracts

import (
	"errors"
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = errors.New
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
	_ = abi.ConvertType
)

// EmergencyAuditMetaData contains all meta data concerning the EmergencyAudit contract.
var EmergencyAuditMetaData = &bind.MetaData{
	ABI: "[{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"logId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"patientId\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"hospitalId\",\"type\":\"string\"}],\"name\":\"DispatchLogged\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"logCount\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"_pId\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"_hId\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"_dept\",\"type\":\"string\"}],\"name\":\"logDispatch\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"logs\",\"outputs\":[{\"internalType\":\"string\",\"name\":\"patientId\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"hospitalId\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"department\",\"type\":\"string\"},{\"internalType\":\"uint256\",\"name\":\"timestamp\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]",
}

// EmergencyAuditABI is the input ABI used to generate the binding from.
// Deprecated: Use EmergencyAuditMetaData.ABI instead.
var EmergencyAuditABI = EmergencyAuditMetaData.ABI

// EmergencyAudit is an auto generated Go binding around an Ethereum contract.
type EmergencyAudit struct {
	EmergencyAuditCaller     // Read-only binding to the contract
	EmergencyAuditTransactor // Write-only binding to the contract
	EmergencyAuditFilterer   // Log filterer for contract events
}

// EmergencyAuditCaller is an auto generated read-only Go binding around an Ethereum contract.
type EmergencyAuditCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// EmergencyAuditTransactor is an auto generated write-only Go binding around an Ethereum contract.
type EmergencyAuditTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// EmergencyAuditFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type EmergencyAuditFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// EmergencyAuditSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type EmergencyAuditSession struct {
	Contract     *EmergencyAudit   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// EmergencyAuditCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type EmergencyAuditCallerSession struct {
	Contract *EmergencyAuditCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// EmergencyAuditTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type EmergencyAuditTransactorSession struct {
	Contract     *EmergencyAuditTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// EmergencyAuditRaw is an auto generated low-level Go binding around an Ethereum contract.
type EmergencyAuditRaw struct {
	Contract *EmergencyAudit // Generic contract binding to access the raw methods on
}

// EmergencyAuditCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type EmergencyAuditCallerRaw struct {
	Contract *EmergencyAuditCaller // Generic read-only contract binding to access the raw methods on
}

// EmergencyAuditTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type EmergencyAuditTransactorRaw struct {
	Contract *EmergencyAuditTransactor // Generic write-only contract binding to access the raw methods on
}

// NewEmergencyAudit creates a new instance of EmergencyAudit, bound to a specific deployed contract.
func NewEmergencyAudit(address common.Address, backend bind.ContractBackend) (*EmergencyAudit, error) {
	contract, err := bindEmergencyAudit(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &EmergencyAudit{EmergencyAuditCaller: EmergencyAuditCaller{contract: contract}, EmergencyAuditTransactor: EmergencyAuditTransactor{contract: contract}, EmergencyAuditFilterer: EmergencyAuditFilterer{contract: contract}}, nil
}

// NewEmergencyAuditCaller creates a new read-only instance of EmergencyAudit, bound to a specific deployed contract.
func NewEmergencyAuditCaller(address common.Address, caller bind.ContractCaller) (*EmergencyAuditCaller, error) {
	contract, err := bindEmergencyAudit(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &EmergencyAuditCaller{contract: contract}, nil
}

// NewEmergencyAuditTransactor creates a new write-only instance of EmergencyAudit, bound to a specific deployed contract.
func NewEmergencyAuditTransactor(address common.Address, transactor bind.ContractTransactor) (*EmergencyAuditTransactor, error) {
	contract, err := bindEmergencyAudit(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &EmergencyAuditTransactor{contract: contract}, nil
}

// NewEmergencyAuditFilterer creates a new log filterer instance of EmergencyAudit, bound to a specific deployed contract.
func NewEmergencyAuditFilterer(address common.Address, filterer bind.ContractFilterer) (*EmergencyAuditFilterer, error) {
	contract, err := bindEmergencyAudit(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &EmergencyAuditFilterer{contract: contract}, nil
}

// bindEmergencyAudit binds a generic wrapper to an already deployed contract.
func bindEmergencyAudit(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := EmergencyAuditMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_EmergencyAudit *EmergencyAuditRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _EmergencyAudit.Contract.EmergencyAuditCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_EmergencyAudit *EmergencyAuditRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _EmergencyAudit.Contract.EmergencyAuditTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_EmergencyAudit *EmergencyAuditRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _EmergencyAudit.Contract.EmergencyAuditTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_EmergencyAudit *EmergencyAuditCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _EmergencyAudit.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_EmergencyAudit *EmergencyAuditTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _EmergencyAudit.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_EmergencyAudit *EmergencyAuditTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _EmergencyAudit.Contract.contract.Transact(opts, method, params...)
}

// LogCount is a free data retrieval call binding the contract method 0xa503898f.
//
// Solidity: function logCount() view returns(uint256)
func (_EmergencyAudit *EmergencyAuditCaller) LogCount(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _EmergencyAudit.contract.Call(opts, &out, "logCount")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// LogCount is a free data retrieval call binding the contract method 0xa503898f.
//
// Solidity: function logCount() view returns(uint256)
func (_EmergencyAudit *EmergencyAuditSession) LogCount() (*big.Int, error) {
	return _EmergencyAudit.Contract.LogCount(&_EmergencyAudit.CallOpts)
}

// LogCount is a free data retrieval call binding the contract method 0xa503898f.
//
// Solidity: function logCount() view returns(uint256)
func (_EmergencyAudit *EmergencyAuditCallerSession) LogCount() (*big.Int, error) {
	return _EmergencyAudit.Contract.LogCount(&_EmergencyAudit.CallOpts)
}

// Logs is a free data retrieval call binding the contract method 0xe79899bd.
//
// Solidity: function logs(uint256 ) view returns(string patientId, string hospitalId, string department, uint256 timestamp)
func (_EmergencyAudit *EmergencyAuditCaller) Logs(opts *bind.CallOpts, arg0 *big.Int) (struct {
	PatientId  string
	HospitalId string
	Department string
	Timestamp  *big.Int
}, error) {
	var out []interface{}
	err := _EmergencyAudit.contract.Call(opts, &out, "logs", arg0)

	outstruct := new(struct {
		PatientId  string
		HospitalId string
		Department string
		Timestamp  *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.PatientId = *abi.ConvertType(out[0], new(string)).(*string)
	outstruct.HospitalId = *abi.ConvertType(out[1], new(string)).(*string)
	outstruct.Department = *abi.ConvertType(out[2], new(string)).(*string)
	outstruct.Timestamp = *abi.ConvertType(out[3], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// Logs is a free data retrieval call binding the contract method 0xe79899bd.
//
// Solidity: function logs(uint256 ) view returns(string patientId, string hospitalId, string department, uint256 timestamp)
func (_EmergencyAudit *EmergencyAuditSession) Logs(arg0 *big.Int) (struct {
	PatientId  string
	HospitalId string
	Department string
	Timestamp  *big.Int
}, error) {
	return _EmergencyAudit.Contract.Logs(&_EmergencyAudit.CallOpts, arg0)
}

// Logs is a free data retrieval call binding the contract method 0xe79899bd.
//
// Solidity: function logs(uint256 ) view returns(string patientId, string hospitalId, string department, uint256 timestamp)
func (_EmergencyAudit *EmergencyAuditCallerSession) Logs(arg0 *big.Int) (struct {
	PatientId  string
	HospitalId string
	Department string
	Timestamp  *big.Int
}, error) {
	return _EmergencyAudit.Contract.Logs(&_EmergencyAudit.CallOpts, arg0)
}

// LogDispatch is a paid mutator transaction binding the contract method 0xf466f97a.
//
// Solidity: function logDispatch(string _pId, string _hId, string _dept) returns()
func (_EmergencyAudit *EmergencyAuditTransactor) LogDispatch(opts *bind.TransactOpts, _pId string, _hId string, _dept string) (*types.Transaction, error) {
	return _EmergencyAudit.contract.Transact(opts, "logDispatch", _pId, _hId, _dept)
}

// LogDispatch is a paid mutator transaction binding the contract method 0xf466f97a.
//
// Solidity: function logDispatch(string _pId, string _hId, string _dept) returns()
func (_EmergencyAudit *EmergencyAuditSession) LogDispatch(_pId string, _hId string, _dept string) (*types.Transaction, error) {
	return _EmergencyAudit.Contract.LogDispatch(&_EmergencyAudit.TransactOpts, _pId, _hId, _dept)
}

// LogDispatch is a paid mutator transaction binding the contract method 0xf466f97a.
//
// Solidity: function logDispatch(string _pId, string _hId, string _dept) returns()
func (_EmergencyAudit *EmergencyAuditTransactorSession) LogDispatch(_pId string, _hId string, _dept string) (*types.Transaction, error) {
	return _EmergencyAudit.Contract.LogDispatch(&_EmergencyAudit.TransactOpts, _pId, _hId, _dept)
}

// EmergencyAuditDispatchLoggedIterator is returned from FilterDispatchLogged and is used to iterate over the raw logs and unpacked data for DispatchLogged events raised by the EmergencyAudit contract.
type EmergencyAuditDispatchLoggedIterator struct {
	Event *EmergencyAuditDispatchLogged // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *EmergencyAuditDispatchLoggedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(EmergencyAuditDispatchLogged)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(EmergencyAuditDispatchLogged)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *EmergencyAuditDispatchLoggedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *EmergencyAuditDispatchLoggedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// EmergencyAuditDispatchLogged represents a DispatchLogged event raised by the EmergencyAudit contract.
type EmergencyAuditDispatchLogged struct {
	LogId      *big.Int
	PatientId  string
	HospitalId string
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterDispatchLogged is a free log retrieval operation binding the contract event 0x4527e0b1cb760af4cef09ecb35345271810c7b3a0f7357e654ba05dac831dfa5.
//
// Solidity: event DispatchLogged(uint256 logId, string patientId, string hospitalId)
func (_EmergencyAudit *EmergencyAuditFilterer) FilterDispatchLogged(opts *bind.FilterOpts) (*EmergencyAuditDispatchLoggedIterator, error) {

	logs, sub, err := _EmergencyAudit.contract.FilterLogs(opts, "DispatchLogged")
	if err != nil {
		return nil, err
	}
	return &EmergencyAuditDispatchLoggedIterator{contract: _EmergencyAudit.contract, event: "DispatchLogged", logs: logs, sub: sub}, nil
}

// WatchDispatchLogged is a free log subscription operation binding the contract event 0x4527e0b1cb760af4cef09ecb35345271810c7b3a0f7357e654ba05dac831dfa5.
//
// Solidity: event DispatchLogged(uint256 logId, string patientId, string hospitalId)
func (_EmergencyAudit *EmergencyAuditFilterer) WatchDispatchLogged(opts *bind.WatchOpts, sink chan<- *EmergencyAuditDispatchLogged) (event.Subscription, error) {

	logs, sub, err := _EmergencyAudit.contract.WatchLogs(opts, "DispatchLogged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(EmergencyAuditDispatchLogged)
				if err := _EmergencyAudit.contract.UnpackLog(event, "DispatchLogged", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseDispatchLogged is a log parse operation binding the contract event 0x4527e0b1cb760af4cef09ecb35345271810c7b3a0f7357e654ba05dac831dfa5.
//
// Solidity: event DispatchLogged(uint256 logId, string patientId, string hospitalId)
func (_EmergencyAudit *EmergencyAuditFilterer) ParseDispatchLogged(log types.Log) (*EmergencyAuditDispatchLogged, error) {
	event := new(EmergencyAuditDispatchLogged)
	if err := _EmergencyAudit.contract.UnpackLog(event, "DispatchLogged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
