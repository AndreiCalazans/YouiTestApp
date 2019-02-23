import {
  ButtonRef,
  Composition,
  ImageRef,
  TextRef,
  TimelineRef,
  ViewRef
} from '@youi/react-native-youi';
import React, { Component } from 'react';
import {
  Animated,
  AppRegistry,
  Button,
  FlatList,
  Image,
  StyleSheet,
  Text,
  View
} from 'react-native';
import movies from '../movies.js'

export class App extends Component {
  constructor() {
    super();
    this.state = {
      movieIndex: 0,
      buttonEnabled: false
    };
  }

  render() {
    let movie = movies[this.state.movieIndex];
    return (
      <View
        style={styles.container}
      >
        <Composition
          source="PDP_Main"
        >
          <TimelineRef
            name="In"
            onLoad={(timeline) => {
              this.inTimeline = timeline;
            }}
            onCompleted={() => {
              this.setState({
                buttonEnabled: true
              });
            }}
          />
          <TimelineRef
            name="Out"
            onLoad={(timeline) => {
              this.outTimeline = timeline;
            }}
            onCompleted={() => {
              this.setState({
                movieIndex: this.nextMovieIndex
              });
            }}
          />
          <TextRef
            name="Title-Text"
            text={movie.title}
          />
          <TextRef
            name="Details-Text"
            text={movie.details}
          />
          <TextRef
            name="Body-Text"
            text={movie.synopsis}
          />
          <ViewRef name="controls" >
            <ButtonRef
              name="Btn-Previous"
              text="Previous"
              enabled={this.state.buttonEnabled}
              onClick={() => {
                this.nextMovieIndex = (this.state.movieIndex + movies.length - 1) % movies.length
                this.outTimeline.play()
                this.setState({
                  buttonEnabled: false
                })
              }}
            />
            <ButtonRef
              name="Btn-Next"
              text="Next"
              enabled={this.state.buttonEnabled}
              onClick={() => {
                this.nextMovieIndex = (this.state.movieIndex + 1) % movies.length
                this.outTimeline.play()
                this.setState({
                  buttonEnabled: false
                })
              }}
            />
          </ViewRef>
          <ImageRef
            name="Image-2x3"
            source={{"uri": "res://drawable/default/2x3-" + movie.image}}
            onLoad={() => {
                this.inTimeline.play()
                console.log("OnLoad fired.")
            }}
            onLoadEnd={() => {
                console.log("OnLoadEnd fired.")
            }}
            onLoadStart={() => {
                console.log("OnLoadStart fired.")
            }}
            onError={() => {
                console.log("OnError fired.")
            }}
          />
          <ImageRef
            name="Image-16x9"
            source={{"uri": "res://drawable/default/16x9-" + movie.image}}
          />
        </Composition>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#d0d0d0'
  },
});
