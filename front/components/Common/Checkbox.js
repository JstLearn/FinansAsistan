// front/components/Common/Checkbox.js
import React from 'react';
import { TouchableOpacity, Text, View, StyleSheet } from 'react-native';
import { GLOBAL_FONT_FAMILY } from '../../styles/styles';

const Checkbox = ({ label, value, onChange, hasError }) => {
  return (
    <View style={{ marginBottom: 15 }}>
      <Text style={styles.formLabel}>
        {label} {hasError && '*'}
      </Text>
      <TouchableOpacity
        style={[
          styles.checkboxButton,
          { backgroundColor: value ? '#4caf50' : '#ccc' },
          hasError && styles.errorBorder,
        ]}
        onPress={onChange}
      >
            <Text style={{ fontFamily: GLOBAL_FONT_FAMILY }}>{value ? 'Evet' : 'Hayır'}</Text>
      </TouchableOpacity>
      {hasError && <Text style={styles.errorText}>{hasError}</Text>}
    </View>
  );
};

const styles = StyleSheet.create({
  formLabel: {
    fontFamily: GLOBAL_FONT_FAMILY,
    color: '#fff',
    marginBottom: 3,
    fontWeight: '500',
  },
  checkboxButton: {
    borderRadius: 12,
    paddingHorizontal: 15,
    paddingVertical: 8,
    alignSelf: 'flex-start',
    marginTop: 5,
  },
  errorBorder: {
    borderColor: 'red',
    borderWidth: 1,
  },
  errorText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    color: 'red',
    marginTop: 5,
  },
});

export default Checkbox;
