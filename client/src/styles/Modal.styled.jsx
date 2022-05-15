import styled from "styled-components";

export const Modal = styled.div`
  position: relative;
  width: 530px;
  height: 700px;
  background-image: url("assets/modal.png");
  background-size: 100% 100%;
  background-repeat: no-repeat;
  background-position: center;
  z-index: 10;
  color: white;
`;

export const Container = styled.div`
  position: relative;
  padding: 60px 40px 30px 40px;
  width: 100%;
  height: 700px;
  display: flex;
  flex-direction: column;
  align-items: center;
`;

export const Header = styled.div`
  margin-top: 30px;

  & > h1 {
    font-size: 3rem;
  }

  & > button {
    position: absolute;
    top: 70px;
    right: 70px;
    background-color: transparent;
    border: none;
    background-image: url("assets/close.png");
    background-size: 100% 100%;
    background-repeat: no-repeat;
    background-position: center;
    width: 48px;
    height: 48px;
  }
`;

export const Button = styled.button`
  position: absolute;
  background-color: transparent;
  border: none;
  background-image: url("assets/button.png");
  width: 70%;
  height: 70px;
  background-repeat: no-repeat;
  background-size: 100% 100%;
  background-position: center;
  color: white;
  bottom: 5px;
  font-size: 2rem;
  bottom: 60px;
`;
