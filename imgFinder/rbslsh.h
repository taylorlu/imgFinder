//////////////////////////////////////////////////////////////////////////////
/// Copyright (C) 2014 Gefu Tang <tanggefu@gmail.com>. All Rights Reserved.
///
/// This file is part of LSHBOX.
///
/// LSHBOX is free software: you can redistribute it and/or modify it under
/// the terms of the GNU General Public License as published by the Free
/// Software Foundation, either version 3 of the License, or(at your option)
/// any later version.
///
/// LSHBOX is distributed in the hope that it will be useful, but WITHOUT
/// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
/// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
/// more details.
///
/// You should have received a copy of the GNU General Public License along
/// with LSHBOX. If not, see <http://www.gnu.org/licenses/>.
///
/// @version 0.1
/// @author Gefu Tang & Zhifeng Xiao
/// @date 2014.6.30
//////////////////////////////////////////////////////////////////////////////

/**
 * @file rbslsh.h
 *
 * @brief Locality-Sensitive Hashing Scheme Based on Random Bits Sampling.
 */
#pragma once
#include <map>
#include <vector>
#include <random>
#include <iostream>
#include <functional>
#include <iostream>
#include <fstream>

namespace lshbox
{
/**
 * A timer object measures elapsed time, and it is very similar to boost::timer.
 */
class timer
{
public:
    timer(): time(double(clock())) {};
    ~timer() {};
    /**
     * Restart the timer.
     */
    void restart()
    {
        time = double(clock());
    }
    /**
     * Measures elapsed time.
     *
     * @return The elapsed time
     */
    double elapsed()
    {
        return (double(clock()) - time) / CLOCKS_PER_SEC;
    }
private:
    double time;
};
/**
 * Locality-Sensitive Hashing Scheme Based on Random Bits Sampling.
 *
 *
 * For more information on random bits sampling based LSH, see the following reference.
 *
 *     P. Indyk and R. Motwani. Approximate Nearest Neighbor - Towards Removing
 *     the Curse of Dimensionality. In Proceedings of the 30th Symposium on Theory
 *     of Computing, 1998, pp. 604-613.
 *
 *     A. Gionis, P. Indyk, and R. Motwani. Similarity search in high dimensions
 *     via hashing. Proceedings of the 25th International Conference on Very Large
 *     Data Bases (VLDB), 1999.
 */
class rbsLsh
{
public:
    struct Parameter
    {
        /// Hash table size
        unsigned M;
        /// Number of hash tables
        unsigned L;
        /// Dimension of the vector, it can be obtained from the instance of Matrix
        unsigned D;
        /// Binary code bytes
        unsigned N;
        /// The Difference between upper and lower bound of each dimension
        unsigned C;
        /// Max KeyPoint Count, should be large enough
        unsigned maxKpointCount;
    };
    struct TopKParam
    {
        int count;
        int dataIndex;
    };
    rbsLsh() {vec=NULL;}
    rbsLsh(const Parameter &param_)
    {
        reset(param_);
    }
    ~rbsLsh() {if(vec!=NULL) free(vec);}
    /**
     * Reset the parameter setting
     *
     * @param param_ A instance of rbsLsh::Parametor, which contains the necessary
     * parameters
     */
    void reset(const Parameter &param_);
    void reset(const Parameter &param_, std::vector<std::vector<unsigned>> &usBits, std::vector<std::vector<unsigned>> &usArray);
    /**
     * Insert a vector to the index.
     *
     * @param key   The sequence number of vector
     * @param domin The pointer to the vector
     */
    void insert(unsigned key, const unsigned char *domin);
    /**
     * Query the approximate nearest neighborholds.
     *
     * @param domin   The pointer to the vector
     * @param topK Top-K scanner, use for scan the approximate nearest neighborholds
     */
    int query(const unsigned char *domin, int *vec, int vec_actual_count, TopKParam *topK, int &index);
    void query(const unsigned *hashVals, int *topK, int &index);
    /**
     * get the hash value of a vector.
     *
     * @param k     The idx of the table
     * @param domin The pointer to the vector
     * @return      The hash value
     */
    unsigned getHashVal(unsigned k, const unsigned char *domin);
    /**
     * Load the index from binary file.
     *
     * @param file The path of binary file.
     */
    void load(const std::string &file);
    /**
     * Save the index as binary file.
     *
     * @param file The path of binary file.
     */
    void save(const std::string &file);
private:
    Parameter param;
    std::vector<std::vector<unsigned> > rndBits;
    std::vector<std::vector<unsigned> > rndArray;
    std::vector<std::vector<std::vector<unsigned> > > tables;
    int *vec;
    int vec_actual_count;
};
}

// ------------------------- implementation -------------------------
void lshbox::rbsLsh::reset(const Parameter &param_)
{
    vec = (int *)malloc(param.maxKpointCount*sizeof(int));
    memset(vec, 0, sizeof(int)*param.maxKpointCount);
    vec_actual_count = 0;
    
    param = param_;
    tables.resize(param.L);
    for(int i=0;i<param.L;i++) {
        tables[i].resize(param.M);
    }
    rndBits.resize(param.L);    //L个哈希表的每个表 存储 N个不重复的 [0, param.D * param.C - 1] 之间的数 按序
    rndArray.resize(param.L);   //L个哈希表的每个表 存储 N个可以重复的 [0, param.M - 1] 之间的数 无序
    std::mt19937 rng(unsigned(std::time(0)));
    std::uniform_int_distribution<unsigned> usBits(0, param.D * param.C - 1);
    for (std::vector<std::vector<unsigned> >::iterator iter = rndBits.begin(); iter != rndBits.end(); ++iter)
    {
        while (iter->size() != param.N)
        {
            unsigned target = usBits(rng);
            if (std::find(iter->begin(), iter->end(), target) == iter->end())
            {
                iter->push_back(target);
            }
        }
        std::sort(iter->begin(), iter->end());
    }
    std::uniform_int_distribution<unsigned> usArray(0, param.M - 1);
    for (std::vector<std::vector<unsigned> >::iterator iter = rndArray.begin(); iter != rndArray.end(); ++iter)
    {
        for (unsigned i = 0; i != param.N; ++i)
        {
            iter->push_back(usArray(rng));
        }
    }
}

void lshbox::rbsLsh::reset(const Parameter &param_, std::vector<std::vector<unsigned>> &usBits, std::vector<std::vector<unsigned>> &usArray)
{
    vec = (int *)malloc(param.maxKpointCount*sizeof(int));
    memset(vec, 0, sizeof(int)*param.maxKpointCount);
    vec_actual_count=0;
    
    param = param_;
    tables.resize(param.L);
    for(int i=0;i<param.L;i++) {
        tables[i].resize(param.M);
    }
    rndBits.resize(param.L);    //L个哈希表的每个表 存储 N个不重复的 [0, param.D * param.C - 1] 之间的数 按序
    rndArray.resize(param.L);   //L个哈希表的每个表 存储 N个可以重复的 [0, param.M - 1] 之间的数 无序
    std::mt19937 rng(unsigned(std::time(0)));
    int Lindex=0;
    for (std::vector<std::vector<unsigned> >::iterator iter = rndBits.begin(); iter != rndBits.end(); ++iter)
    {
        int j=0;
        std::vector<unsigned> usBit = usBits[Lindex++];
        while (iter->size() != param.N)
        {
            unsigned target = usBit[j++];
            iter->push_back(target);
        }
    }
    Lindex=0;
    for (std::vector<std::vector<unsigned> >::iterator iter = rndArray.begin(); iter != rndArray.end(); ++iter)
    {
        for (unsigned i = 0; i != param.N; ++i)
        {
            iter->push_back(usArray[Lindex][i]);
        }
        Lindex++;
    }
}

void lshbox::rbsLsh::insert(unsigned key, const unsigned char *domin)
{
    for (unsigned k = 0; k != param.L; ++k)
    {
        unsigned hashVal = getHashVal(k, domin);
        tables[k][hashVal].push_back(key);
    }
    vec_actual_count++;
}
void lshbox::rbsLsh::query(const unsigned *hashVals, int *topK, int &index)
{
    for (unsigned k = 0; k != param.L; ++k)
    {
        unsigned hashval = hashVals[k];
        if (tables[k][hashval].size()!=0)
        {
            for (std::vector<unsigned>::iterator iter = tables[k][hashval].begin(); iter != tables[k][hashval].end(); ++iter)
            {
                vec[*iter]++;
            }
        }
    }
    
    for(int i=0; i<vec_actual_count; i++) {
        if(vec[i]>=4) { //L=5, need match at least 4 hashTables
            topK[index] = i;
            index++;
        }
    }
    memset(vec, 0, vec_actual_count*sizeof(int));
}

int lshbox::rbsLsh::query(const unsigned char *domin, int *vec, int vec_actual_count, TopKParam *topK, int &index)
{
    for (unsigned k = 0; k != param.L; ++k)
    {
        unsigned hashVal = getHashVal(k, domin);
        if (tables[k][hashVal].size()!=0)
        {
            for (std::vector<unsigned>::iterator iter = tables[k][hashVal].begin(); iter != tables[k][hashVal].end(); ++iter)
            {
                vec[*iter]++;
            }
        }
    }

    for(int i=0; i<vec_actual_count; i++) {
        if(vec[i]>=4) { //L=5, need match at least 4 hashTables
            topK[index].dataIndex = i;
            topK[index].count = vec[i];
            index++;
        }
    }
    return 0;
}
unsigned lshbox::rbsLsh::getHashVal(unsigned k, const unsigned char *domin)
{
    unsigned sum(0), seq(0);
    for (std::vector<unsigned>::iterator it = rndBits[k].begin(); it != rndBits[k].end(); ++it)
    {
        if ((*it % param.C) <= unsigned(domin[*it / param.C]))  // *it 是不重复的有序的
        {
            sum += rndArray[k][seq];
        }
        ++seq;
    }
    unsigned hashVal = sum % param.M;   //返回一个 [0, param.M - 1] 的数值,也就是第k个哈希表的index
    return hashVal;
}
void lshbox::rbsLsh::load(const std::string &file)
{
    std::ifstream in(file, std::ios::binary);
    in.read((char *)&param.M, sizeof(unsigned));
    in.read((char *)&param.L, sizeof(unsigned));
    in.read((char *)&param.D, sizeof(unsigned));
    in.read((char *)&param.C, sizeof(unsigned));
    in.read((char *)&param.N, sizeof(unsigned));
    tables.resize(param.L);
    for(int i=0;i<param.L;i++) {
        tables[i].resize(param.M);
    }
    rndBits.resize(param.L);
    rndArray.resize(param.L);
    for (unsigned i = 0; i != param.L; ++i)
    {
        rndBits[i].resize(param.N);
        rndArray[i].resize(param.N);
        in.read((char *)&rndBits[i][0], sizeof(unsigned) * param.N);
        in.read((char *)&rndArray[i][0], sizeof(unsigned) * param.N);
        unsigned count;
        in.read((char *)&count, sizeof(unsigned));
        for (unsigned j = 0; j != count; ++j)
        {
            unsigned target;
            in.read((char *)&target, sizeof(unsigned));
            unsigned length;
            in.read((char *)&length, sizeof(unsigned));
            tables[i][target].resize(length);
            in.read((char *) & (tables[i][target][0]), sizeof(unsigned) * length);
            if(i==0) {
                vec_actual_count += length;
            }
        }
    }
    in.close();
}
void lshbox::rbsLsh::save(const std::string &file)
{
    std::ofstream out(file, std::ios::binary);
    out.write((char *)&param.M, sizeof(unsigned));
    out.write((char *)&param.L, sizeof(unsigned));
    out.write((char *)&param.D, sizeof(unsigned));
    out.write((char *)&param.C, sizeof(unsigned));
    out.write((char *)&param.N, sizeof(unsigned));
    for (int i = 0; i != param.L; ++i)
    {
        out.write((char *)&rndBits[i][0], sizeof(unsigned) * param.N);
        out.write((char *)&rndArray[i][0], sizeof(unsigned) * param.N);
        unsigned count = unsigned(tables[i].size());
        out.write((char *)&count, sizeof(unsigned));
        
        for (int index = 0; index < tables[i].size(); ++index)
        {
            unsigned target = index;
            out.write((char *)&target, sizeof(unsigned));
            unsigned length = unsigned(tables[i][index].size());
            out.write((char *)&length, sizeof(unsigned));
            out.write((char *) & (tables[i][index][0]), sizeof(unsigned) * length);
        }
    }
    out.close();
}
