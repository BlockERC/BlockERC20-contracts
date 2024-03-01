// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library String {
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;

        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    function toLower(string memory str) internal pure returns (string memory) {
		bytes memory bStr = bytes(str);
		bytes memory bLower = new bytes(bStr.length);
		for (uint i = 0; i < bStr.length; i++) {
			if (uint8(bStr[i]) >= 65 && uint8(bStr[i]) <= 90) {
				bLower[i] = bytes1(uint8(bStr[i]) + 32);
			} else {
				bLower[i] = bStr[i];
			}
		}
		return string(bLower);
	}

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeApprove: approve failed'
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}

library Logarithm {
    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return msb The index of the most significant bit as an uint256.
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        if (x >= 2**128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2**64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2**32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2**16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2**1) {
            // No need to shift x any more.
            msb += 1;
        }
    }
    /// @notice Calculates the binary logarithm of x.
    ///
    /// @dev Based on the iterative approximation algorithm.
    /// https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
    ///
    /// Requirements:
    /// - x must be greater than zero.
    ///
    /// Caveats:
    /// - The results are nor perfectly accurate to the last digit, due to the lossy precision of the iterative approximation.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the binary logarithm.
    /// @return result The binary logarithm as a signed 59.18-decimal fixed-point number.
    function log2(int256 x, int256 scale, int256 halfScale) internal pure returns (int256 result) {
        require(x > 0);
        unchecked {
            // This works because log2(x) = -log2(1/x).
            int256 sign;
            if (x >= scale) {
                sign = 1;
            } else {
                sign = -1;
                // Do the fixed-point inversion inline to save gas. The numerator is SCALE * SCALE.
                assembly {
                    x := div(1000000000000000000000000000000000000, x)
                }
            }

            // Calculate the integer part of the logarithm and add it to the result and finally calculate y = x * 2^(-n).
            uint256 n = mostSignificantBit(uint256(x / scale));

            // The integer part of the logarithm as a signed 59.18-decimal fixed-point number. The operation can't overflow
            // because n is maximum 255, SCALE is 1e18 and sign is either 1 or -1.
            result = int256(n) * scale;

            // This is y = x * 2^(-n).
            int256 y = x >> n;

            // If y = 1, the fractional part is zero.
            if (y == scale) {
                return result * sign;
            }

            // Calculate the fractional part via the iterative approximation.
            // The "delta >>= 1" part is equivalent to "delta /= 2", but shifting bits is faster.
            for (int256 delta = int256(halfScale); delta > 0; delta >>= 1) {
                y = (y * y) / scale;

                // Is y^2 > 2 and so in the range [2,4)?
                if (y >= 2 * scale) {
                    // Add the 2^(-m) factor to the logarithm.
                    result += delta;

                    // Corresponds to z/2 on Wikipedia.
                    y >>= 1;
                }
            }
            result *= sign;
        }
    }
}

// This is common token interface, get balance of owner's token by ERC20/ERC721/ERC1155.
interface ICommonToken {
    function balanceOf(address owner) external returns(uint256);
}

interface IConfig {
    struct Config {
        uint256 inscriptionId;
        uint256 maxMintSize;
        uint256 freezeTime;
        address onlyContractAddress;
        uint256 onlyMinQuantity;
        uint256 baseFee;
        uint256 fundingCommission;
        uint256 crowdFundingRate;
        address crowdFundingAddress;
        address inscriptionFactory;
    }
}

// This contract is extended from ERC20
contract Inscription is ERC20 {
    using Logarithm for int256;
    uint256 public cap;                 // Max amount
    uint256 public limitPerMint;        // Limitaion of each mint
    uint256 public inscriptionId;       // Inscription Id
    uint256 public maxMintSize;         // max mint size, that means the max mint quantity is: maxMintSize * limitPerMint
    uint256 public freezeTime;          // The frozen time (interval) between two mints is a fixed number of seconds. You can mint, but you will need to pay an additional mint fee, and this fee will be double for each mint.
    address public onlyContractAddress; // Only addresses that hold these assets can mint
    uint256 public onlyMinQuantity;     // Only addresses that the quantity of assets hold more than this amount can mint
    uint256 public baseFee;             // base fee of the second mint after frozen interval. The first mint after frozen time is free.
    uint256 public fundingCommission;   // commission rate of fund raising, 100 means 1%
    uint256 public crowdFundingRate;    // rate of crowdfunding
    address payable public crowdfundingAddress; // receiving fee of crowdfunding
    address payable public inscriptionFactory;

    mapping(address => uint256) public lastMintTimestamp;   // record the last mint timestamp of account
    mapping(address => uint256) public lastMintFee;           // record the last mint fee

    constructor(
        string memory _name,            // token name
        string memory _tick,            // token tick, same as symbol. must be 4 characters.
        uint256 _cap,                   // Max amount
        uint256 _limitPerMint,          // Limitaion of each mint
        // uint256 _inscriptionId,         // Inscription Id
        // uint256 _maxMintSize,           // max mint size, that means the max mint quantity is: maxMintSize * limitPerMint. This is only availabe for non-frozen time token.
        // uint256 _freezeTime,            // The frozen time (interval) between two mints is a fixed number of seconds. You can mint, but you will need to pay an additional mint fee, and this fee will be double for each mint.
        // address _onlyContractAddress,   // Only addresses that hold these assets can mint
        // uint256 _onlyMinQuantity,       // Only addresses that the quantity of assets hold more than this amount can mint
        // uint256 _baseFee,               // base fee of the second mint after frozen interval. The first mint after frozen time is free.
        // uint256 _fundingCommission,     // commission rate of fund raising, 100 means 1%
        // uint256 _crowdFundingRate,      // rate of crowdfunding
        // address payable _crowdFundingAddress,   // receiving fee of crowdfunding
        // address payable _inscriptionFactory
        IConfig.Config memory _config
    ) ERC20(_name, _tick) {
        require(_cap >= _limitPerMint, "Limit per mint exceed cap");
        cap = _cap;
        limitPerMint = _limitPerMint;
        // inscriptionId = _inscriptionId;
        // maxMintSize = _maxMintSize;
        // freezeTime = _freezeTime;
        // onlyContractAddress = _onlyContractAddress;
        // onlyMinQuantity = _onlyMinQuantity;
        // baseFee = _baseFee;
        // fundingCommission = _fundingCommission;
        // crowdFundingRate = _crowdFundingRate;
        // crowdfundingAddress = _crowdFundingAddress;
        // inscriptionFactory = _inscriptionFactory;
        limitPerMint = limitPerMint;
        inscriptionId = _config.inscriptionId;
        maxMintSize = _config.maxMintSize;
        freezeTime = _config.freezeTime;
        onlyContractAddress = payable(_config.onlyContractAddress);
        onlyMinQuantity = _config.onlyMinQuantity;
        baseFee = _config.baseFee;
        fundingCommission = _config.fundingCommission;
        crowdFundingRate = _config.crowdFundingRate;
        crowdfundingAddress = payable(_config.crowdFundingAddress);
        inscriptionFactory = payable(_config.inscriptionFactory);
    }

    function mint(address _to) payable public {
        require(!isContract(msg.sender), "caller can't be contract");
        // Check if the quantity after mint will exceed the cap
        require(totalSupply() + limitPerMint <= cap, "Touched cap");
        // Check if the assets in the msg.sender is satisfied
        require(onlyContractAddress == address(0x0) || ICommonToken(onlyContractAddress).balanceOf(msg.sender) >= onlyMinQuantity, "You don't have required assets");
        
        if(lastMintTimestamp[msg.sender] + freezeTime > block.timestamp) {
            // The min extra tip is double of last mint fee
            lastMintFee[msg.sender] = lastMintFee[msg.sender] == 0 ? baseFee : lastMintFee[msg.sender] * 2;
            // Transfer the fee to the crowdfunding address
            if(crowdFundingRate >= 0) {
                // Check if the tip is high than the min extra fee
                require(msg.value >= crowdFundingRate + lastMintFee[msg.sender], "Send some ETH as fee and crowdfunding");
                // _dispatchFunding(crowdFundingRate);
                _dispatchFunding(msg.value);
            }
            // Transfer the tip to InscriptionFactory smart contract
            // if(msg.value - crowdFundingRate > 0) TransferHelper.safeTransferETH(inscriptionFactory, msg.value - crowdFundingRate);
        } else {
            // Transfer the fee to the crowdfunding address
            if(crowdFundingRate > 0) {
                require(msg.value >= crowdFundingRate, "Send some ETH as crowdfunding");
                _dispatchFunding(msg.value);
            }
            // Out of frozen time, free mint. Reset the timestamp and mint times.
            lastMintFee[msg.sender] = 0;
            lastMintTimestamp[msg.sender] = block.timestamp;
        }
        // Do mint
        _mint(_to, limitPerMint);
    }

    // batch mint is only available for non-frozen-time tokens
    // function batchMint(address _to, uint256 _num) payable public {
    //     require(_num <= maxMintSize, "exceed max mint size");
    //     require(totalSupply() + _num * limitPerMint <= cap, "Touch cap");
    //     require(freezeTime == 0, "Batch mint only for non-frozen token");
    //     require(onlyContractAddress == address(0x0) || ICommonToken(onlyContractAddress).balanceOf(msg.sender) >= onlyMinQuantity, "You don't have required assets");
    //     if(crowdFundingRate > 0) {
    //         require(msg.value >= crowdFundingRate * _num, "Crowdfunding ETH not enough");
    //         _dispatchFunding(msg.value);
    //     }
    //     for(uint256 i = 0; i < _num; i++) _mint(_to, limitPerMint);
    // }

    function getMintFee(address _addr) public view returns(uint256 mintedTimes, uint256 nextMintFee) {
        if(lastMintTimestamp[_addr] + freezeTime > block.timestamp) {
            int256 scale = 1e18;
            int256 halfScale = 5e17;
            // times = log_2(lastMintFee / baseFee) + 1 (if lastMintFee > 0)
            nextMintFee = lastMintFee[_addr] == 0 ? baseFee : lastMintFee[_addr] * 2;
            mintedTimes = uint256((Logarithm.log2(int256(nextMintFee / baseFee) * scale, scale, halfScale) + 1) / scale) + 1;
        }
    }

    function _dispatchFunding(uint256 _amount) private {
        TransferHelper.safeTransferETH(inscriptionFactory, _amount);
        // uint256 commission = _amount * fundingCommission / 10000;
        // TransferHelper.safeTransferETH(crowdfundingAddress, _amount - commission);
        // if(commission > 0) TransferHelper.safeTransferETH(inscriptionFactory, commission);
    }


    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }
}

contract InscriptionFactory is Ownable{
    using Counters for Counters.Counter;
    Counters.Counter private _inscriptionNumbers;

    uint8 public maxTickSize = 5;                   // tick(symbol) length is 4.
    uint256 public baseFee = 250000000000000;       // Will charge 0.00025 ETH as extra min tip from the second time of mint in the frozen period. And this tip will be double for each mint.
    uint256 public fundingCommission = 100;       // commission rate of fund raising, 100 means 1%

    mapping(uint256 => Token) private inscriptions; // key is inscription id, value is token data
    mapping(string => uint256) private ticks;       // Key is tick, value is inscription id

    event DeployInscription(
        uint256 indexed id, 
        string tick, 
        string name, 
        uint256 cap, 
        uint256 limitPerMint, 
        address inscriptionAddress, 
        uint256 timestamp
    );

    struct Token {
        string tick;            // same as symbol in ERC20
        string name;            // full name of token
        uint256 cap;            // Hard cap of token
        uint256 limitPerMint;   // Limitation per mint
        uint256 maxMintSize;    // // max mint size, that means the max mint quantity is: maxMintSize * limitPerMint
        uint256 inscriptionId;  // Inscription id
        uint256 freezeTime;
        address onlyContractAddress;
        uint256 onlyMinQuantity;
        uint256 crowdFundingRate;
        address crowdfundingAddress;
        address addr;           // Contract address of inscribed token 
        uint256 timestamp;      // Inscribe timestamp
    }

    constructor() {
        // The inscription id will be from 1, not zero.
        _inscriptionNumbers.increment();
    }

    // Let this contract accept ETH as tip
    receive() external payable {}
    
    function deploy(
        string memory _name,
        string memory _tick,
        uint256 _cap,
        uint256 _limitPerMint,
        uint256 _maxMintSize, // The max lots of each mint
        uint256 _freezeTime, // Freeze seconds between two mint, during this freezing period, the mint fee will be increased 
        address _onlyContractAddress, // Only the holder of this asset can mint, optional
        uint256 _onlyMinQuantity, // The min quantity of asset for mint, optional
        uint256 _crowdFundingRate,
        address _crowdFundingAddress
    ) external returns (address _inscriptionAddress) {
        require(String.strlen(_tick) <= maxTickSize, "Tick lenght should be less 5");
        require(_cap >= _limitPerMint, "Limit per mint exceed cap");

        _tick = String.toLower(_tick);
        require(this.getIncriptionIdByTick(_tick) == 0, "tick is existed");

        // Create inscription contract
        bytes memory bytecode = type(Inscription).creationCode;
        uint256 _id = _inscriptionNumbers.current();
		// bytecode = abi.encodePacked(bytecode, abi.encode(
        //     _name, 
        //     _tick, 
        //     _cap, 
        //     _limitPerMint, 
        //     _id, 
        //     _maxMintSize,
        //     _freezeTime,
        //     _onlyContractAddress,
        //     _onlyMinQuantity,
        //     baseFee,
        //     fundingCommission,
        //     _crowdFundingRate,
        //     _crowdFundingAddress,
        //     address(this)
        // ));

        {
            bytecode = abi.encodePacked(bytecode, abi.encode(
            _name, 
            _tick, 
            _cap, 
            _limitPerMint, 
            IConfig.Config({
                inscriptionId: _id,
                maxMintSize: _maxMintSize,
                freezeTime: _freezeTime,
                onlyContractAddress: _onlyContractAddress,
                onlyMinQuantity: _onlyMinQuantity,
                baseFee: baseFee,
                fundingCommission: fundingCommission,
                crowdFundingRate: _crowdFundingRate,
                crowdFundingAddress: _crowdFundingAddress,
                inscriptionFactory: address(this)
                })
            ));

            bytes32 salt = keccak256(abi.encodePacked(_id));
            assembly ("memory-safe") {
                _inscriptionAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
                if iszero(extcodesize(_inscriptionAddress)) {
                    revert(0, 0)
                }
            }
        }
        inscriptions[_id] = Token(
            _tick, 
            _name, 
            _cap, 
            _limitPerMint, 
            _maxMintSize,
            _id,
            _freezeTime,
            _onlyContractAddress,
            _onlyMinQuantity,
            _crowdFundingRate,
            _crowdFundingAddress,
            _inscriptionAddress, 
            block.timestamp
        );
        ticks[_tick] = _id;

        _inscriptionNumbers.increment();
        emit DeployInscription(_id, _tick, _name, _cap, _limitPerMint, _inscriptionAddress, block.timestamp);
    }

    function getInscriptionAmount() external view returns(uint256) {
        return _inscriptionNumbers.current() - 1;
    }

    function getIncriptionIdByTick(string memory _tick) external view returns(uint256) {
        return ticks[String.toLower(_tick)];
    }

    function getIncriptionById(uint256 _id) external view returns(Token memory, uint256) {
        Token memory token = inscriptions[_id];
        return (inscriptions[_id], Inscription(token.addr).totalSupply());
    }

    function getIncriptionByTick(string memory _tick) external view returns(Token memory tokens, uint256 totalSupplies) {
        Token memory token = inscriptions[this.getIncriptionIdByTick(_tick)];
        uint256 id = this.getIncriptionIdByTick(String.toLower(_tick));
        if(id > 0) {
            tokens = inscriptions[id];
            totalSupplies = Inscription(token.addr).totalSupply();
        }
    }

    function getInscriptionAmountByType(uint256 _type) external view returns(uint256) {
        require(_type < 3, "type is 0-2");
        uint256 totalInscription = this.getInscriptionAmount();
        uint256 count = 0;
        for(uint256 i = 1; i <= totalInscription; i++) {
            (Token memory _token, uint256 _totalSupply) = this.getIncriptionById(i);
            if(_type == 1 && _totalSupply == _token.cap) continue;
            else if(_type == 2 && _totalSupply < _token.cap) continue;
            else count++;
        }
        return count;
    }
    
    // Fetch inscription data by page no, page size, type and search keyword
    function getIncriptions(
        uint256 _pageNo, 
        uint256 _pageSize, 
        uint256 _type // 0- all, 1- in-process, 2- ended
    ) external view returns(
        Token[] memory, 
        uint256[] memory
    ) {
        // if _searchBy is not empty, the _pageNo and _pageSize should be set to 1
        require(_type < 3, "type is 0-2");
        uint256 totalInscription = this.getInscriptionAmount();
        uint256 pages = (totalInscription - 1) / _pageSize + 1;
        require(_pageNo > 0 && _pageSize > 0 && pages > 0 && _pageNo <= pages, "Params wrong");

        Token[] memory inscriptions_ = new Token[](_pageSize);
        uint256[] memory totalSupplies_ = new uint256[](_pageSize);

        Token[] memory _inscriptions = new Token[](totalInscription);
        uint256[] memory _totalSupplies = new uint256[](totalInscription);

        uint256 index = 0;
        {
            for(uint256 i = 1; i <= totalInscription; i++) {
                (Token memory _token, uint256 _totalSupply) = this.getIncriptionById(i);
                if((_type == 1 && _totalSupply == _token.cap) || (_type == 2 && _totalSupply < _token.cap)) continue; 
                else {
                    _inscriptions[index] = _token;
                    _totalSupplies[index] = _totalSupply;
                    index++;
                }
            }
        }

        {
            uint256 _pageNo2 = _pageNo;
            for(uint256 i = 0; i < _pageSize; i++) {
                uint256 id = (_pageNo2 - 1) * _pageSize + i;
                if(id < index) {
                    inscriptions_[i] = _inscriptions[id];
                    totalSupplies_[i] = _totalSupplies[id];
                } else break;
            }
        }

        return (inscriptions_, totalSupplies_);
    }

    // Withdraw the ETH tip from the contract
    function withdraw(address payable _to, uint256 _amount) external onlyOwner {
        require(_amount <= payable(address(this)).balance);
        TransferHelper.safeTransferETH(_to, _amount);
    }

    // Update base fee
    function updateBaseFee(uint256 _fee) external onlyOwner {
        baseFee = _fee;
    }

    // Update funding commission
    function updateFundingCommission(uint256 _rate) external onlyOwner {
        fundingCommission = _rate;
    }

    // Update character's length of tick
    function updateTickSize(uint8 _size) external onlyOwner {
        maxTickSize = _size;
    }
}
