import React, { Component } from 'react';
import logo from '../assets/logo.svg';
import styled from 'styled-components';

class App extends Component {
  render() {
  	const Title = styled.h1`
	  font-size: 1.5em;
	  text-align: center;
	  color: palevioletred;
	`;


    return (
      <div className="App">
        <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
          <h1 className="App-title">Welcome to React</h1>
        </header>
        <p className="App-intro">
          To get started, edit <code>src/App.js</code> and save to reload.
        </p>
        <Title>Title</Title>
      </div>
    );
  }
}

export default App;
