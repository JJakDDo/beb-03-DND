// SPDX-License-Identifier: MIT
pragma solidity ^0.5.6;

import "@klaytn/contracts/token/KIP7/KIP7.sol";
import "@klaytn/contracts/token/KIP7/IKIP7.sol";
import "@klaytn/contracts/token/KIP7/KIP7Metadata.sol";
import "@klaytn/contracts/math/SafeMath.sol";
import "./Token.sol";

interface IExchange {
    function klayToTokenSwap(uint256 _minTokens) external payable;

    function klayToTokenTransfer(uint256 _minTokens, address _recipient)
        external
        payable;
}

interface IFactory {
    function getExchange(address _tokenAddress) external view returns (address);
}

contract Exchange is KIP7, KIP7Metadata {

    using SafeMath for uint256;

    address public tokenAddress;
    address public factoryAddress;   // 모든 거래소 contract는 factory 주소를 알 수 있어야 함
    Token public uru;

    constructor(address _token, Token _uru) public KIP7Metadata("klay-uru-LP-token", "LP", 18)  {
        require(_token != address(0), "invalid token address");
        tokenAddress = _token;
        uru = _uru;
        factoryAddress = msg.sender;  // factory address link
    }

    function addLiquidity(uint256 _tokenAmount) public payable returns (uint256) {

        if(getReserve() == 0) { // 풀에 token 유동성이 없을때

            // 현재 유동성 고려없이 입력받은 _tokenAmount 만큼 유동성을 주입한다.
            KIP7 token = KIP7(tokenAddress);
            token.transferFrom(msg.sender, address(this), _tokenAmount);
            
            // 현 컨트랙트 pool에 전송 받은 liquidity 지분이 모두 msg.sender이므로
            // 해당 liquidity 만큼 _mint 하여 LP 토큰을 발행한다.
            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity); // LP 토큰 mint
            
            return liquidity;

        } else { // 풀에 token 유동성이 이미 존재하는 경우

            // 이미있는 유동성에 입력받은 _tokenAmount 만큼 더해지면
            // 얼마나 유동성에 지분이 있는지 liquidity를 계산하는 식
            uint256 klayReserve = address(this).balance.sub(msg.value);
            uint256 tokenReserve = getReserve();
            uint256 tokenAmount = (msg.value.mul(tokenReserve)).div(klayReserve);

            // 입력받은 토큰 양이 더 크면 유동성이 없거나 더 빠지는 경우이므로 유효성검사를 해준다.
            require(_tokenAmount >= tokenAmount, "insufficient token amount");

            // 입력받은 _tokenAmount가 아닌 위에서 유동성을 고려하여 계산한 tokenAmount 만큼 
            // 유동성을 주입받는다.
            KIP7 token = KIP7(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);

            // 그리고 그 liquidity 만큼 LP 토큰을 발행한다.
            uint256 liquidity = (totalSupply().mul(msg.value)).div(klayReserve);
            _mint(msg.sender, liquidity);

            return liquidity;
        }
    }

    function removeLiquidity(uint256 _amount) public returns (uint256, uint256) {
        
        require(_amount > 0, "invalid amount");

        // klayAmount : 현재 풀에 _amount가 추가된 만큼의 유동성이 고려된 klay의 양
        uint256 klayAmount = (address(this).balance.mul(_amount)).div(totalSupply());
        // tokenAmount : 현재 풀에 _amount가 추가된 만큼 유동성이 고려된 token의 양
        uint256 tokenAmount = (getReserve().mul(_amount)).div(totalSupply());

        // 입력받은 _amount 만큼 burn
        _burn(msg.sender, _amount);

        // ------(이후 정책에 따라 removeLiquidity 수수료, 이자 등 적용)

        // msg.sender에게 계산한 klayAmount 반환
        msg.sender.transfer(klayAmount);

        // 풀에서 msg.sender 에게 계산한 tokenAmount 반환
        KIP7(tokenAddress).transfer(msg.sender, tokenAmount);

        return (klayAmount, tokenAmount);
    }

    function getKlay() public view returns (uint256 balance) {
        balance =  address(this).balance;
    }

    function getReserve() public view returns (uint256 balance) {
        balance =  KIP7(tokenAddress).balanceOf(address(this)); 
    }

    function getTokenAmount(uint256 _klaySold) public view returns (uint256) { // klay의 양을 받고 교환해 줄 토큰의 양을 출력하는 함수
        require(_klaySold > 0, "klaySold is too small");

        uint256 tokenReserve = getReserve();

        return getAmount(_klaySold, address(this).balance, tokenReserve); // 교환해 줄 토큰의 양 (y)
    }

    function getKlayAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0, "tokenSold is too small");

        uint256 tokenReserve = getReserve();

        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    function klayToToken(uint256 _minTokens, address recipient) public payable { // 교환해 줄 토큰의 양을 미리 알고 있다는 이상한 가정
        uint256 tokenReserve = getReserve(); // 풀의 토큰 잔액
        uint256 tokensBought = getAmount(
            msg.value, // 입금한 klay
            address(this).balance.sub(msg.value), // 풀에있는 klay의 양
            tokenReserve // 풀에 있는 토큰의 양
        );

        require(tokensBought >= _minTokens, "insufficient output amount"); // 교환해 줄 토큰이 모자라면 안된다

        // 수정 : Factory 가 설정되는 거래소 토큰스왑 로직에 따라 msg.sender 가 바뀌므로
        //       klayToTokenSwap 을 klayToToken, klayToTokenSwap 함수로 나눈다.
        
        //-- 참고 : msg.sender 는 동적으로 바뀌며, 사용자가 컨트랙트를 호출하면 '사용자의 주소'를 나타낸다.
        //         하지만 한 컨트랙트가 다른 컨트랙트를 호출하면, '호출하는 컨트랙트의 주소'를 나타낸다.
        //         https://jeiwan.net/posts/programming-defi-uniswap-3/

        KIP7(tokenAddress).transfer(recipient, tokensBought);
        // KIP7(tokenAddress).transfer(msg.sender, tokensBought); // tokenBought = 교환해 줄 토큰의 양을 msg.sender에게 보내 준다.
    }
    
    function klayToTokenSwap(uint256 _minTokens) public payable {
        klayToToken(_minTokens, msg.sender);
    }

    function klayToTokenTransfer(uint256 _minTokens, address _recipient)
        public
        payable
    {
        klayToToken(_minTokens, _recipient);
    }

    function tokenToKlaySwap(uint256 _tokensSold, uint256 _minklay) public {

        uint256 tokenReserve = getReserve(); // 풀에 있는 토큰의 양
        uint256 klayBought = getAmount(
            _tokensSold, // 입급한 토큰의 양
            tokenReserve, // 풀에 있는 토큰의 양
            address(this).balance // 풀에 있는 klay의 양
        );

        require(klayBought >= _minklay, "insufficient output amount");

        KIP7(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold); // msg.sender에게 컨트랙트 주소로 토큰을 보내게 한다.
        msg.sender.transfer(klayBought); // msg.sender에게 klaybought 만큼의 클레이를 보내 준다.
    }

    /*
    * tokenToTokenSwap
    * 1. Factory에서 입력받은 사용자의 토큰 주소를 가진 거래소를 찾는다.
    * 2. 거래소가 존재하면, 입력받은 사용자가 sold 한 만큼의 토큰의 양을 해당 거래소로 보내 토큰으로 교환한다.
    * 3. 교환된 토큰을 사용자에게 반환한다.
    */

    function tokenToTokenSwap(uint256 _tokensSold, uint256 _minTokensBought, address _tokenAddress) 
    public {

        // 1. Factory 에서 토큰 주소가 존재하는 거래소 주소를 받아온다.
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
        
        // 거래소 주소 유효성 검사
        require(
            exchangeAddress != address(this) && exchangeAddress != address(0),
            "invalid exchange address"
        );

        uint256 tokenReserve = getReserve();    // 풀의 token 
        uint256 klayBought = getAmount(         // token을 팔면 얼마의 klay 를 얻는지(풀의 유동성 고려)
            _tokensSold,
            tokenReserve,
            address(this).balance               // 풀의 klay 양
        );

        // 2. msg.sender가 token을 sold한만큼 풀에 전송하게 함
        // msg.sender : first exchange contract address
        KIP7(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);

        // 3. 구입한 klayBought 만큼  
        // msg.sender : exchangeAddress
        IExchange(exchangeAddress).klayToTokenTransfer.value(klayBought)(
            _minTokensBought,
            msg.sender
        );
    }

    function getAmount( // x(지불할 토큰)의 양을 넣으면 교환해 줄 y의 양을 출력하는 함수
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve 
    ) private pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        uint256 inputAmountWithFee = inputAmount.mul(99); // 수수료를 제한다.
        uint256 numerator = inputAmountWithFee.mul(outputReserve);
        uint256 denominator = (inputReserve.mul(100)).add(inputAmountWithFee);

        return numerator.div(denominator);

        // return (inputAmount * outputReserve) / (inputReserve + inputAmount); 수수료 없을 때의 경우
    }

    // LP-Farming feature
    
    // iterations을 위한 배열 선언
    address[] public userList;

    // 관련 정보를 기록할 mapping 선언
    mapping(address => uint256) public stakingBalance;
    mapping(address => bool) public isStaking;
    mapping(address => uint256) public startTime;
    mapping(address => uint256) public URUBalance;

    event Stake(address indexed from, uint256 amount);
    event Unstake(address indexed from, uint256 amount);
    event YieldWithdraw(address indexed to, uint256 amount);

    //  예치 기능
    function stake(uint256 amount) public {
        require(
            amount > 0 &&
            KIP7(address(this)).balanceOf(msg.sender) >= amount, 
            "토큰이 부족합니다");

        // userList에 "없는 주소일 경우" msg.sender을 주소를 userList에 삽입
        if(isStaking[msg.sender] == false) {
            userList.push(msg.sender);
        }
        
        if(isStaking[msg.sender] == true) {
            URUBalance[msg.sender] = URUBalance[msg.sender].add(calculateYieldTotal(msg.sender));
        }

        stakingBalance[msg.sender] = stakingBalance[msg.sender].add(amount);
        KIP7(address(this)).transferFrom(msg.sender, address(this), amount);
        startTime[msg.sender] = block.timestamp;
        isStaking[msg.sender] = true;
        emit Stake(msg.sender, amount);

        // stake가 일어날 때 마다 모든 유저에 대해서 해당 시각의 이자를 mapping 결과에 저장
        for (uint256 i = 0; i < userList.length; i++) {
            uint256 nowURUBalance = calculateYieldTotal(userList[i]);
            URUBalance[userList[i]] = URUBalance[userList[i]].add(nowURUBalance);
            startTime[userList[i]] = block.timestamp;
        }
    }

    // 예치량 빼기
    function unstake(uint256 amount) public {
        require(
            isStaking[msg.sender] = true &&
            stakingBalance[msg.sender] >= amount, 
            "예치량보다 많습니다"
        );
        uint256 yieldTransfer = calculateYieldTotal(msg.sender);
        startTime[msg.sender] = block.timestamp;
        uint256 balTransfer = amount;
        amount = 0;
        stakingBalance[msg.sender] = stakingBalance[msg.sender].sub(balTransfer);
        KIP7(address(this)).transfer(msg.sender, balTransfer);
        URUBalance[msg.sender] = URUBalance[msg.sender].add(yieldTransfer);
        if(stakingBalance[msg.sender] == 0){
            isStaking[msg.sender] = false;
            // 예치량이 0이되면 userList에서 해당 함수의 주소를 삭제
        }
        emit Unstake(msg.sender, balTransfer);

        // stake가 일어날 때와의 마찬가지의 논리
        for (uint256 i = 0; i < userList.length; i++) {
        uint256 nowURUBalance = calculateYieldTotal(userList[i]);
        URUBalance[userList[i]] = URUBalance[userList[i]].add(nowURUBalance);
        startTime[userList[i]] = block.timestamp;
        }
    }

    // 현재 스테이킹 중인 address를 배열로 반환
    function getuserList() public view returns(address[] memory) {
        return userList;
    }

    // 마지막 스테이킹 변화로부터 시간 측정 (블록타임 활용)
    function calculateYieldTime(address user) public view returns(uint256){
        uint256 end = block.timestamp;
        uint256 totalTime = end.sub(startTime[user]);
        return totalTime;
    }

    // 전체 비율 중 해당 유저의 유동성 기여도 측정
    // 소수점 둘째 자리까지 가능 (백분율)
    function calculateContribute(address user) public view returns(uint256){
        uint contribution = (stakingBalance[user].mul(100)).div(KIP7(address(this)).balanceOf(address(this)));
        return contribution;
    }

    // 새로운 기간 동안 (새로운 stake나 unstake가 일어나지 않는 동안) 각 유저에게 지급할 이자를 계산
    // 시간과 기여도의 곱으로 계산
    // 총 분당 1500개, 초당 25개씩 발행될 것이고 이를 기여도에 따라서 나누는 시스템
    function calculateYieldTotal(address user) public view returns(uint256) {
        uint256 time = calculateYieldTime(user);
        uint256 contribution = calculateContribute(user);
        uint256 rawYield = (time.mul(contribution).mul(25));
        return rawYield;
    } 

    // URUBalance에 저장된 값과 현재 기간 쌓인 이자의 합으로 mint해줌
    function withdrawYield() public {
        uint256 toTransfer = calculateYieldTotal(msg.sender);

        require(
            toTransfer > 0 ||
            URUBalance[msg.sender] > 0,
            "Nothing to withdraw"
            );
                    
        if(URUBalance[msg.sender] != 0){
            uint256 oldBalance = URUBalance[msg.sender];
            URUBalance[msg.sender] = 0;
            toTransfer = toTransfer.add(oldBalance);
        }

        startTime[msg.sender] = block.timestamp;
        uru.mint(msg.sender, toTransfer);
        emit YieldWithdraw(msg.sender, toTransfer);
    } 
}
