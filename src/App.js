import React, { Component } from 'react';
import { Video } from '@youi/react-native-youi';
import {
  StyleSheet,
  Text,
  View
} from 'react-native';

export class App extends React.Component {
  videoRef;

  render() {
    return (
      <View style={styles.container}>
        <Video 
          style={styles.video}
          ref={(videoRef) => {
            this.videoRef = videoRef;
          }}
          onReady={() => {
            this.videoRef.play();
          }}
          source={{
            uri: 'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
            type: 'HLS'
          }}
        />
      </View>
    )
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#d0d0d0'
  },
  video: {
    flex: 1,
  },
});
