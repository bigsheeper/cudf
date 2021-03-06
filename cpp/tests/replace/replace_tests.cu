/*
 * Copyright 2018 BlazingDB, Inc.
 *     Copyright 2018 Cristhian Alberto Gonzales Castillo <cristhian@blazingdb.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include <cudf/replace.hpp>
#include <cudf/null_mask.hpp>
#include <tests/utilities/base_fixture.hpp>
#include <tests/utilities/column_wrapper.hpp>
#include <tests/utilities/cudf_gtest.hpp>
#include <tests/utilities/type_lists.hpp>
#include <tests/utilities/column_utilities.hpp>

#include <cudf/cudf.h>
#include <bitmask/legacy/bit_mask.cuh>

#include <thrust/device_vector.h>


#include <gtest/gtest.h>
#include <cstdlib>
#include <iostream>
#include <vector>

struct ReplaceErrorTest : public cudf::test::BaseFixture{};

// Error: old-values and new-values size mismatch
TEST_F(ReplaceErrorTest, SizeMismatch)
{

  cudf::test::fixed_width_column_wrapper<int32_t> gdf_input_column{ {7, 5, 6, 3, 1, 2, 8, 4}};
  cudf::test::fixed_width_column_wrapper<int32_t> gdf_values_to_replace_column{ {10, 11, 12, 13}};
  cudf::test::fixed_width_column_wrapper<int32_t> gdf_replacement_values_column{ {15, 16, 17}};

  EXPECT_THROW(cudf::experimental::find_and_replace_all(gdf_input_column,
                                                        gdf_values_to_replace_column,
                                                        gdf_replacement_values_column,
                                                        mr()),
               cudf::logic_error);
}

// Error: column type mismatch
TEST_F(ReplaceErrorTest, TypeMismatch)
{

  cudf::test::fixed_width_column_wrapper<int32_t> gdf_input_column{ {7, 5, 6, 3, 1, 2, 8, 4}};
  cudf::test::fixed_width_column_wrapper<float> gdf_values_to_replace_column{ {10, 11, 12}};
  cudf::test::fixed_width_column_wrapper<int32_t> gdf_replacement_values_column{ {15, 16, 17}};

  EXPECT_THROW(cudf::experimental::find_and_replace_all(gdf_input_column,
                                                        gdf_values_to_replace_column,
                                                        gdf_replacement_values_column,
                                                        mr()),
               cudf::logic_error);
}

// Error: nulls in old-values
TEST_F(ReplaceErrorTest, NullInOldValues)
{
  cudf::test::fixed_width_column_wrapper<int32_t> gdf_input_column{ {7, 5, 6, 3, 1, 2, 8, 4}};
  cudf::test::fixed_width_column_wrapper<int32_t> gdf_values_to_replace_column{ {10, 11, 12, 13}, {1, 0, 0, 1}};
  cudf::test::fixed_width_column_wrapper<int32_t> gdf_replacement_values_column{ {15, 16, 17, 18}};

  EXPECT_THROW(cudf::experimental::find_and_replace_all(gdf_input_column,
                                                        gdf_values_to_replace_column,
                                                        gdf_replacement_values_column,
                                                        mr()),
               cudf::logic_error);
}

struct ReplaceStringsTest : public cudf::test::BaseFixture{};

// Strings test
TEST_F(ReplaceStringsTest, Strings) {
  std::vector<std::string> input{"a","b","c","d","e","f","g","h"};
  std::vector<std::string> values_to_replace{"a"};
  std::vector<std::string> replacement{"z"};

  cudf::test::strings_column_wrapper input_wrapper{input.begin(), input.end()};
  cudf::test::strings_column_wrapper values_to_replace_wrapper{values_to_replace.begin(), values_to_replace.end()};
  cudf::test::strings_column_wrapper replacement_wrapper{replacement.begin(), replacement.end()};

  std::unique_ptr<cudf::column> result;
  ASSERT_NO_THROW(result = cudf::experimental::find_and_replace_all(input_wrapper,
                                                           values_to_replace_wrapper,
                                                           replacement_wrapper,
                                                           mr()));
  std::vector<std::string> expected{"z","b","c","d","e","f","g","h"};
  std::vector<cudf::valid_type> ex_valid{1,1,1,1,1,1,1,1};
  cudf::test::strings_column_wrapper expected_wrapper{expected.begin(), expected.end(), ex_valid.begin()};

  cudf::test::expect_columns_equal(*result, expected_wrapper);
}

// Strings test
TEST_F(ReplaceStringsTest, StringsReplacementNulls) {
  std::vector<std::string> input{"a","b","c","d","e","f","g","h"};
  std::vector<std::string> values_to_replace{"a","b"};
  std::vector<std::string> replacement{"z",""};
  std::vector<cudf::valid_type> replacement_valid{1,0};
  cudf::test::strings_column_wrapper input_wrapper{input.begin(), input.end()};
  cudf::test::strings_column_wrapper values_to_replace_wrapper{values_to_replace.begin(), values_to_replace.end()};
  cudf::test::strings_column_wrapper replacement_wrapper{replacement.begin(), replacement.end(), replacement_valid.begin()};

  std::unique_ptr<cudf::column> result;
  ASSERT_NO_THROW(result = cudf::experimental::find_and_replace_all(input_wrapper,
                                                           values_to_replace_wrapper,
                                                           replacement_wrapper,
                                                           mr()));
  std::vector<std::string> expected{"z","","c","d","e","f","g","h"};
  std::vector<cudf::valid_type> ex_valid{1,0,1,1,1,1,1,1};
  cudf::test::strings_column_wrapper expected_wrapper{expected.begin(), expected.end(), ex_valid.begin()};

  cudf::test::expect_columns_equal(*result, expected_wrapper);
}

// Strings test
TEST_F(ReplaceStringsTest, StringsResultAllNulls) {
  std::vector<std::string> input{"b","b","b","b","b","b","b","b"};
  std::vector<std::string> values_to_replace{"a","b"};
  std::vector<std::string> replacement{"a",""};
  std::vector<cudf::valid_type> replacement_valid{1,0};
  std::vector<std::string> expected{"","","","","","","",""};
  std::vector<cudf::valid_type> ex_valid{0,0,0,0,0,0,0,0};
  cudf::test::strings_column_wrapper input_wrapper{input.begin(), input.end()};
  cudf::test::strings_column_wrapper values_to_replace_wrapper{values_to_replace.begin(), values_to_replace.end()};
  cudf::test::strings_column_wrapper replacement_wrapper{replacement.begin(), replacement.end(), replacement_valid.begin()};

  std::unique_ptr<cudf::column> result;
  ASSERT_NO_THROW(result = cudf::experimental::find_and_replace_all(input_wrapper,
                                                           values_to_replace_wrapper,
                                                           replacement_wrapper,
                                                           mr()));
  cudf::test::strings_column_wrapper expected_wrapper{expected.begin(), expected.end(), ex_valid.begin()};

  cudf::test::expect_columns_equal(*result, expected_wrapper);
}

// Strings test
TEST_F(ReplaceStringsTest, StringsResultAllEmpty) {
  std::vector<std::string> input{"b","b","b","b","b","b","b","b"};
  std::vector<std::string> values_to_replace{"a","b"};
  std::vector<std::string> replacement{"a",""};
  std::vector<cudf::valid_type> replacement_valid{1,1};
  std::vector<std::string> expected{"","","","","","","",""};
  std::vector<cudf::valid_type> ex_valid{1,1,1,1,1,1,1,1};
  cudf::test::strings_column_wrapper input_wrapper{input.begin(), input.end()};
  cudf::test::strings_column_wrapper values_to_replace_wrapper{values_to_replace.begin(), values_to_replace.end()};
  cudf::test::strings_column_wrapper replacement_wrapper{replacement.begin(), replacement.end(), replacement_valid.begin()};

  std::unique_ptr<cudf::column> result;
  ASSERT_NO_THROW(result = cudf::experimental::find_and_replace_all(input_wrapper,
                                                           values_to_replace_wrapper,
                                                           replacement_wrapper,
                                                           mr()));
  cudf::test::strings_column_wrapper expected_wrapper{expected.begin(), expected.end(), ex_valid.begin()};

  cudf::test::expect_columns_equal(*result, expected_wrapper);
}

// Strings test
TEST_F(ReplaceStringsTest, StringsInputNulls) {
  std::vector<std::string> input{"a","b","","","e","f","g","h"};
  std::vector<std::string> values_to_replace{"a","b"};
  std::vector<std::string> replacement{"z","y"};
  std::vector<cudf::valid_type> input_valid{1,1,0,0,1,1,1,1};
  cudf::test::strings_column_wrapper input_wrapper{input.begin(), input.end(), input_valid.begin()};
  cudf::test::strings_column_wrapper values_to_replace_wrapper{values_to_replace.begin(), values_to_replace.end()};
  cudf::test::strings_column_wrapper replacement_wrapper{replacement.begin(), replacement.end()};

  std::unique_ptr<cudf::column> result;
  ASSERT_NO_THROW(result = cudf::experimental::find_and_replace_all(input_wrapper,
                                                           values_to_replace_wrapper,
                                                           replacement_wrapper,
                                                           mr()));
  std::vector<std::string> expected{"z","y","","","e","f","g","h"};
  std::vector<cudf::valid_type> ex_valid{1,1,0,0,1,1,1,1};
  cudf::test::strings_column_wrapper expected_wrapper{expected.begin(), expected.end(), ex_valid.begin()};

  cudf::test::expect_columns_equal(*result, expected_wrapper);
}

// Strings test
TEST_F(ReplaceStringsTest, StringsInputAndReplacementNulls) {
  std::vector<std::string> input{"a","b","","","e","f","g","h"};
  std::vector<std::string> values_to_replace{"a","b"};
  std::vector<std::string> replacement{"z",""};
  std::vector<cudf::valid_type> replacement_valid{1,0};
  std::vector<cudf::valid_type> input_valid{1,1,0,0,1,1,1,1};
  cudf::test::strings_column_wrapper input_wrapper{input.begin(), input.end(), input_valid.begin()};
  cudf::test::strings_column_wrapper values_to_replace_wrapper{values_to_replace.begin(), values_to_replace.end()};
  cudf::test::strings_column_wrapper replacement_wrapper{replacement.begin(), replacement.end(), replacement_valid.begin()};

  std::unique_ptr<cudf::column> result;
  ASSERT_NO_THROW(result = cudf::experimental::find_and_replace_all(input_wrapper,
                                                           values_to_replace_wrapper,
                                                           replacement_wrapper,
                                                           mr()));
  std::vector<std::string> expected{"z","","","","e","f","g","h"};
  std::vector<cudf::valid_type> ex_valid{1,0,0,0,1,1,1,1};
  cudf::test::strings_column_wrapper expected_wrapper{expected.begin(), expected.end(), ex_valid.begin()};

  cudf::test::expect_columns_equal(*result, expected_wrapper);
}

// Strings test
TEST_F(ReplaceStringsTest, StringsEmptyReplacement) {
  std::vector<std::string> input{"a","b","","","e","f","g","h"};
  std::vector<std::string> values_to_replace{};
  std::vector<std::string> replacement{};
  std::vector<cudf::valid_type> input_valid{1,1,0,0,1,1,1,1};
  cudf::test::strings_column_wrapper input_wrapper{input.begin(), input.end(), input_valid.begin()};
  cudf::test::strings_column_wrapper values_to_replace_wrapper{values_to_replace.begin(), values_to_replace.end()};
  cudf::test::strings_column_wrapper replacement_wrapper{replacement.begin(), replacement.end()};

  std::unique_ptr<cudf::column> result;
  ASSERT_NO_THROW(result = cudf::experimental::find_and_replace_all(input_wrapper,
                                                           values_to_replace_wrapper,
                                                           replacement_wrapper,
                                                           mr()));
  std::vector<std::string> expected{"a","b","","","e","f","g","h"};
  std::vector<cudf::valid_type> ex_valid{1,1,0,0,1,1,1,1};
  cudf::test::strings_column_wrapper expected_wrapper{expected.begin(), expected.end(), ex_valid.begin()};

  cudf::test::expect_columns_equal(*result, expected_wrapper);
}

// Strings test
TEST_F(ReplaceStringsTest, StringsLargeScale) {
  std::vector<std::string> input{"a","b","","","e","f","g","h"};
  std::vector<std::string> values_to_replace{"a","b"};
  std::vector<std::string> replacement{"z",""};
  std::vector<cudf::valid_type> replacement_valid{1,0};
  std::vector<cudf::valid_type> input_valid{1,1,0,0,1,1,1,1};
  std::vector<std::string> expected{"z","","","","e","f","g","h"};
  std::vector<cudf::valid_type> ex_valid{1,0,0,0,1,1,1,1};

  std::vector<std::string> big_input{};
  std::vector<cudf::valid_type> big_input_valid{};
  std::vector<std::string> big_expected{};
  std::vector<cudf::valid_type> big_ex_valid{};

  for (int i = 0; i < 10000; i++) {
    int ind = i % input.size();
    big_input.push_back(input[ind]);
    big_input_valid.push_back(input_valid[ind]);
    big_expected.push_back(expected[ind]);
    big_ex_valid.push_back(ex_valid[ind]);
  }

  cudf::test::strings_column_wrapper expected_wrapper{big_expected.begin(), big_expected.end(), big_ex_valid.begin()};

  cudf::test::strings_column_wrapper input_wrapper{big_input.begin(), big_input.end(), big_input_valid.begin()};
  cudf::test::strings_column_wrapper values_to_replace_wrapper{values_to_replace.begin(), values_to_replace.end()};
  cudf::test::strings_column_wrapper replacement_wrapper{replacement.begin(), replacement.end(), replacement_valid.begin()};

  std::unique_ptr<cudf::column> result;
  ASSERT_NO_THROW(result = cudf::experimental::find_and_replace_all(input_wrapper,
                                                           values_to_replace_wrapper,
                                                           replacement_wrapper,
                                                           mr()));


  cudf::test::expect_columns_equal(*result, expected_wrapper);
}


//// This is the main test feature
template <class T>
struct ReplaceTest : cudf::test::BaseFixture
{

  ReplaceTest()
  {
    // Use constant seed so the psuedo-random order is the same each time
    // Each time the class is constructed a new constant seed is used
    static size_t number_of_instantiations{0};
    std::srand(number_of_instantiations++);
  }

  ~ReplaceTest()
  {
  }
};

/* --------------------------------------------------------------------------*
   * @brief Main method for testing.
   * Initializes the input columns with the given values. Then compute the actual
   * resultant column by invoking `cudf::find_and_replace_all()` and then
   * compute the expected column.
   *
   * @param input_column The original values
   * @param values_to_replace_column The values that will be replaced
   * @param replacement_values_column The new values
   * @param input_column_valid The mask for replace column
   * @param replacement_values_valid The mask for new values
   * @param print Optionally print the set of columns for debug
   * -------------------------------------------------------------------------*/
template <typename T>
void test_replace(std::vector<T> const &input_column,
                  std::vector<T> const &values_to_replace_column,
                  std::vector<T> const &replacement_values_column,
                  std::vector<cudf::valid_type> const& input_column_valid =
                     std::vector<cudf::valid_type>{},
                  std::vector<cudf::valid_type> const& replacement_values_valid =
                     std::vector<cudf::valid_type>{},
                  bool print = false) {

    cudf::test::fixed_width_column_wrapper<T> gdf_input_column(input_column.begin(),
                                                               input_column.end());
    if (input_column_valid.size() > 0) {
      gdf_input_column = cudf::test::fixed_width_column_wrapper<T>(input_column.begin(),
                                                                   input_column.end(),
                                                                   input_column_valid.begin());
    }

    cudf::test::fixed_width_column_wrapper<T> gdf_values_to_replace_column(values_to_replace_column.begin(),
                                                                           values_to_replace_column.end());
    cudf::test::fixed_width_column_wrapper<T> gdf_replacement_values_column(replacement_values_column.begin(),
                                                                            replacement_values_column.end());
    if (replacement_values_valid.size() > 0) {
      gdf_replacement_values_column = cudf::test::fixed_width_column_wrapper<T>(replacement_values_column.begin(),
                                                                                replacement_values_column.end(),
                                                                                replacement_values_valid.begin());
    }

    /* getting the actual result*/
    std::unique_ptr<cudf::column> actual_result;
    ASSERT_NO_THROW( actual_result = cudf::experimental::find_and_replace_all(gdf_input_column,
                                                                              gdf_values_to_replace_column,
                                                                              gdf_replacement_values_column));

    /* computing the expected result */
    std::vector<T> reference_result(input_column);
    std::vector<bool> isReplaced(reference_result.size(), false);
    std::vector<cudf::valid_type> expected_valid(input_column_valid);
    if (replacement_values_valid.size() > 0 && 0 == input_column_valid.size()){
        expected_valid.assign(input_column.size(), true);
    }

    const bool input_has_nulls = (input_column_valid.size() > 0);
    const bool replacement_has_nulls = (replacement_values_valid.size() > 0);

    for(size_t i = 0; i < values_to_replace_column.size(); i++)
    {
      size_t k = 0;
      auto pred = [=, &k, &reference_result, &expected_valid, &isReplaced](T element) {
        bool toBeReplaced = false;
        if(!isReplaced[k])
        {
        if(!input_has_nulls || expected_valid[k]){
          if(element == values_to_replace_column[i]) {
          toBeReplaced = true;
          isReplaced[k] = toBeReplaced;
            if(replacement_has_nulls && !replacement_values_valid[i]){
              if(print) std::cout << "clearing bit at: "<<k<<"\n";
              expected_valid[k] = false;
            }
          }
         }
        }

        ++k;
        return toBeReplaced;
      };
      std::replace_if(reference_result.begin(), reference_result.end(),
                      pred, replacement_values_column[i]);
    }

    cudf::test::fixed_width_column_wrapper<T> expected(reference_result.begin(),
                                                       reference_result.end());
    if (expected_valid.size() > 0)
      expected = cudf::test::fixed_width_column_wrapper<T>(reference_result.begin(),
                                                           reference_result.end(),
                                                           expected_valid.begin());

    expect_columns_equal(expected, *actual_result);
}


using Types = cudf::test::NumericTypes;

TYPED_TEST_CASE(ReplaceTest, Types);

// Simple test, replacing all even gdf_replacement_values_column
TYPED_TEST(ReplaceTest, ReplaceEvenPosition)
{
  using T = TypeParam;
  std::vector<T> input_column = cudf::test::make_type_param_vector<T>({1, 2, 3, 4, 5, 6, 7, 8});
  std::vector<T> values_to_replace_column = cudf::test::make_type_param_vector<T>({2, 6, 4, 8});
  std::vector<T> replacement_values_column = cudf::test::make_type_param_vector<T>({0, 4, 2, 6});

  test_replace<T>(input_column, values_to_replace_column, replacement_values_column);
}

// Similar test as ReplaceEvenPosition, but with unordered data
TYPED_TEST(ReplaceTest, Unordered)
{
  using T = TypeParam;
  std::vector<T> input_column = cudf::test::make_type_param_vector<T>({7, 5, 6, 3, 1, 2, 8, 4});
  std::vector<T> values_to_replace_column = cudf::test::make_type_param_vector<T>({2, 6, 4, 8});
  std::vector<T> replacement_values_column = cudf::test::make_type_param_vector<T>({0, 4, 2, 6});

  test_replace<T>(input_column, values_to_replace_column, replacement_values_column);
}

// Testing with Nothing To Replace
TYPED_TEST(ReplaceTest, NothingToReplace)
{
  using T = TypeParam;
  std::vector<T> input_column = cudf::test::make_type_param_vector<T>({7, 5, 6, 3, 1, 2, 8, 4});
  std::vector<T> values_to_replace_column = cudf::test::make_type_param_vector<T>({10, 11, 12});
  std::vector<T> replacement_values_column = cudf::test::make_type_param_vector<T>({15, 16, 17});

  test_replace<T>(input_column, values_to_replace_column, replacement_values_column);
}

// Testing with empty Data
TYPED_TEST(ReplaceTest, EmptyData)
{
  using T = TypeParam;
  std::vector<T> input_column{{}};
  std::vector<T> values_to_replace_column = cudf::test::make_type_param_vector<T>({10, 11, 12});
  std::vector<T> replacement_values_column = cudf::test::make_type_param_vector<T>({15, 16, 17});

  test_replace<T>(input_column, values_to_replace_column, replacement_values_column);
}

// Testing with empty Replace
TYPED_TEST(ReplaceTest, EmptyReplace)
{
  using T = TypeParam;
  std::vector<T> input_column = cudf::test::make_type_param_vector<T>({7, 5, 6, 3, 1, 2, 8, 4});
  std::vector<T> values_to_replace_column{};
  std::vector<T> replacement_values_column{};

  test_replace<T>(input_column, values_to_replace_column, replacement_values_column);
}

// Testing with input column containing nulls
TYPED_TEST(ReplaceTest, NullsInData)
{
  using T = TypeParam;
  std::vector<T> input_column = cudf::test::make_type_param_vector<T>({7, 5, 6, 3, 1, 2, 8, 4});
  std::vector<cudf::valid_type> input_column_valid{1,1,1,0,0,1,1,1};
  std::vector<T> values_to_replace_column = cudf::test::make_type_param_vector<T>({2, 6, 4, 8});
  std::vector<T> replacement_values_column = cudf::test::make_type_param_vector<T>({0, 4, 2, 6});

  test_replace<T>(input_column, values_to_replace_column, replacement_values_column, input_column_valid);
}

// Testing with replacement column containing nulls
TYPED_TEST(ReplaceTest, NullsInNewValues)
{
  using T = TypeParam;
  std::vector<T> input_column = cudf::test::make_type_param_vector<T>({7, 5, 6, 3, 1, 2, 8, 4});
  std::vector<T> values_to_replace_column = cudf::test::make_type_param_vector<T>({2, 6, 4, 8});
  std::vector<T> replacement_values_column = cudf::test::make_type_param_vector<T>({0, 4, 2, 6});
  std::vector<cudf::valid_type> replacement_values_valid{0, 1, 1, 1};

  test_replace<TypeParam>(input_column,
                          values_to_replace_column,
                          replacement_values_column,
                          {},
                          replacement_values_valid);
}


// Testing with both replacement and input column containing nulls
TYPED_TEST(ReplaceTest, NullsInBoth)
{
  using T = TypeParam;
  std::vector<T> input_column = cudf::test::make_type_param_vector<T>({7, 5, 6, 3, 1, 2, 8, 4});
  std::vector<cudf::valid_type> input_column_valid{1,1,1,0,0,1,1,1};
  std::vector<T> values_to_replace_column = cudf::test::make_type_param_vector<T>({2, 6, 4, 8});
  std::vector<T> replacement_values_column = cudf::test::make_type_param_vector<T>({0, 4, 2, 6});
  std::vector<cudf::valid_type> replacement_values_valid{1,1,0,1};

  test_replace<TypeParam>(input_column,
                          values_to_replace_column,
                          replacement_values_column,
                          input_column_valid,
                          replacement_values_valid);
}

// Test with much larger data sets
TYPED_TEST(ReplaceTest, LargeScaleReplaceTest)
{
  const size_t DATA_SIZE    = 1000000;
  const size_t REPLACE_SIZE = 10000;

  thrust::host_vector<TypeParam> input_column(DATA_SIZE);
  std::generate(
    std::begin(input_column),
    std::end(input_column),
    [REPLACE_SIZE] () { return std::rand() % (REPLACE_SIZE); });

  std::vector<TypeParam> values_to_replace_column(REPLACE_SIZE);
  std::vector<TypeParam> replacement_values_column(REPLACE_SIZE);
  size_t count = 0;
  for (size_t i = 0; i < 7; i++) {
    for (size_t j = 0; j < REPLACE_SIZE; j += 7) {
      if (i + j < REPLACE_SIZE) {
        values_to_replace_column[i + j] = count;
        count++;
        replacement_values_column[i + j] = count;
      }
    }
  }
  cudf::test::fixed_width_column_wrapper<TypeParam> gdf_input_column( input_column.begin(), input_column.end());
  cudf::test::fixed_width_column_wrapper<TypeParam> gdf_values_to_replace_column( values_to_replace_column.begin(),
                                                                                  values_to_replace_column.end());
  cudf::test::fixed_width_column_wrapper<TypeParam> gdf_replacement_values_column(replacement_values_column.begin(),
                                                                                  replacement_values_column.end());

  std::unique_ptr<cudf::column> actual_result;
  ASSERT_NO_THROW( actual_result = cudf::experimental::find_and_replace_all(gdf_input_column,
                                                                            gdf_values_to_replace_column,
                                                                            gdf_replacement_values_column));

  std::for_each(input_column.begin(), input_column.end(), [](TypeParam& d) { d += 1; });
  cudf::test::fixed_width_column_wrapper<TypeParam> expected(input_column.begin(), input_column.end());
  expect_columns_equal(expected, *actual_result);
}

CUDF_TEST_PROGRAM_MAIN()
