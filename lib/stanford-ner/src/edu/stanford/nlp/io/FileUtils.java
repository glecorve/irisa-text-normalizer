package edu.stanford.nlp.io;

import edu.stanford.nlp.util.StreamGobbler;
import edu.stanford.nlp.util.StringUtils;

import java.lang.reflect.InvocationTargetException;
import java.util.*;
import java.io.*;
import java.net.InetAddress;
import java.util.regex.Pattern;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

public class FileUtils {

  public static final String eolChar = System.getProperty("line.separator");
  private static final String defaultEnc = "utf-8";

  private FileUtils() {} // just static methods

  /**
   * Get a input file stream (automatically gunzip/bunzip2 depending on file extension)
   * @param filename Name of file to open
   * @return Input stream that can be used to read from the file
   * @throws IOException if there are exceptions opening the file
   */
  public static InputStream getFileInputStream(String filename) throws IOException {
    InputStream in = new FileInputStream(filename);
    if (filename.endsWith(".gz")) {
      in = new GZIPInputStream(in);
    } else if (filename.endsWith(".bz2")) {
      //in = new CBZip2InputStream(in);
      in = getBZip2PipedInputStream(filename);
    }
    return in;
  }

  /**
   * Get a output file stream (automatically gzip/bzip2 depending on file extension)
   * @param filename Name of file to open
   * @return Output stream that can be used to write to the file
   * @throws IOException if there are exceptions opening the file
   */
  public static OutputStream getFileOutputStream(String filename) throws IOException {
    OutputStream out = new FileOutputStream(filename);
    if (filename.endsWith(".gz")) {
      out = new GZIPOutputStream(out);
    } else if (filename.endsWith(".bz2")) {
      //out = new CBZip2OutputStream(out);
      out = getBZip2PipedOutputStream(filename);
    }
    return out;
  }

  public static BufferedReader getBufferedFileReader(String filename) throws IOException {
    return getBufferedFileReader(filename, defaultEnc);
  }

  public static BufferedReader getBufferedFileReader(String filename, String encoding) throws IOException {
    InputStream in = getFileInputStream(filename);
    return new BufferedReader(new InputStreamReader(in, encoding));
  }

  public static PrintWriter getPrintWriter(String filename) throws IOException {
    return getPrintWriter(filename, defaultEnc);
  }

  public static PrintWriter getPrintWriter(String filename, String encoding) throws IOException {
    OutputStream out = getFileOutputStream(filename);
    return new PrintWriter(new BufferedWriter(new OutputStreamWriter(out, encoding)));
  }

  public static InputStream getBZip2PipedInputStream(String filename) throws IOException
  {
    String bzcat = System.getProperty("bzcat", "bzcat");
    Runtime rt = Runtime.getRuntime();
    String cmd = bzcat + " " + filename;
    //System.err.println("getBZip2PipedInputStream: Running command: "+cmd);
    Process p = rt.exec(cmd);
    Writer errWriter = new BufferedWriter(new OutputStreamWriter(System.err));
    StreamGobbler errGobler = new StreamGobbler(p.getErrorStream(), errWriter);
    errGobler.start();
    return p.getInputStream();
  }

  public static OutputStream getBZip2PipedOutputStream(String filename) throws IOException
  {
    return new BZip2PipedOutputStream(filename);
  }

  private static final Pattern tab = Pattern.compile("\t");
  /**
   * Read column as set
   * @param infile - filename
   * @param field  index of field to read
   * @return a set of the entries in column field
   * @throws IOException
   */
  public static Set<String> readColumnSet(String infile, int field) throws IOException
  {
    BufferedReader br = FileUtils.getBufferedFileReader(infile);
    String line;
    Set<String> set = new HashSet<String>();
    while ((line = br.readLine()) != null) {
      line = line.trim();
      if (line.length() > 0) {
        if (field < 0) {
          set.add(line);
        } else {
          String[] fields = tab.split(line);
          if (field < fields.length) {
            set.add(fields[field]);
          }
        }
      }
    }
    br.close();
    return set;
  }

  public static <C> List<C> readObjectFromColumns(Class objClass, String filename, String[] fieldNames, String delimiter)
          throws IOException, InstantiationException, IllegalAccessException,
          NoSuchFieldException, NoSuchMethodException, InvocationTargetException
  {
    Pattern delimiterPattern = Pattern.compile(delimiter);
    List<C> list = new ArrayList<C>();
    BufferedReader br = FileUtils.getBufferedFileReader(filename);
    String line;
    while ((line = br.readLine()) != null) {
      line = line.trim();
      if (line.length() > 0) {
        C item = StringUtils.<C>columnStringToObject(objClass, line, delimiterPattern, fieldNames);
        list.add(item);
      }
    }
    br.close();
    return list;
  }

  public static Map<String,String> readMap(String filename) throws IOException
  {
    Map<String,String> map = new HashMap<String,String>();
    try {
      BufferedReader br = FileUtils.getBufferedFileReader(filename);
      String line;
      while ((line = br.readLine()) != null) {
        String[] fields = tab.split(line,2);
        map.put(fields[0], fields[1]);
      }
    } catch (IOException ex) {
      throw new RuntimeException(ex);
    }
    return map;
  }


  /**
   * Returns the contents of a file as a single string.  The string may be
   * empty, if the file is empty.  If there is an IOException, it is caught
   * and null is returned.
   */
  public static String stringFromFile(String filename) {
    return stringFromFile(filename,defaultEnc);
  }

  /**
   * Returns the contents of a file as a single string.  The string may be
   * empty, if the file is empty.  If there is an IOException, it is caught
   * and null is returned.  Encoding can also be specified.
   */
  public static String stringFromFile(String filename, String encoding) {
    try {
      StringBuilder sb = new StringBuilder();
      BufferedReader in = new BufferedReader(new EncodingFileReader(filename,encoding));
      String line;
      while ((line = in.readLine()) != null) {
        sb.append(line);
        sb.append(eolChar);
      }
      in.close();
      return sb.toString();
    }
    catch (IOException e) {
      e.printStackTrace();
      return null;
    }
  }


  /**
   * Returns the contents of a file as a list of strings.  The list may be
   * empty, if the file is empty.  If there is an IOException, it is caught
   * and null is returned.
   */
  public static List<String> linesFromFile(String filename) {
    return linesFromFile(filename,defaultEnc);
  }

  /**
   * Returns the contents of a file as a list of strings.  The list may be
   * empty, if the file is empty.  If there is an IOException, it is caught
   * and null is returned. Encoding can also be specified
   */
  public static List<String> linesFromFile(String filename,String encoding) {
    try {
      List<String> lines = new ArrayList<String>();
      BufferedReader in = new BufferedReader(new EncodingFileReader(filename,encoding));
      String line;
      while ((line = in.readLine()) != null) {
        lines.add(line);
      }
      in.close();
      return lines;
    }
    catch (IOException e) {
      e.printStackTrace();
      return null;
    }
  }

  public static String backupName(String filename) {
    return backupFile(new File(filename)).toString();
  }

  public static File backupFile(File file) {
    int max = 1000;
    String filename = file.toString();
    File backup = new File(filename + "~");
    if (!backup.exists()) { return backup; }
    for (int i = 1; i <= max; i++) {
      backup = new File(filename + ".~" + i + ".~");
      if (!backup.exists()) { return backup; }
    }
    return null;
  }

  public static boolean renameToBackupName(File file) {
    return file.renameTo(backupFile(file));
  }


  /**
   * A JavaNLP specific convenience routine for obtaining the current
   * scratch directory for the machine you're currently running on.
   */
  public static File getJNLPLocalScratch()  {
    try {
      String machineName = InetAddress.getLocalHost().getHostName().split("\\.")[0];
      String username = System.getProperty("user.name");
      return new File("/"+machineName+"/scr1/"+username);
    } catch (Exception e) {
      return new File("./scr/"); // default scratch
    }
  }

  /**
   * Given a filepath, makes sure a directory exists there.  If not, creates and returns it.
   * Same as ENSURE-DIRECTORY in CL.
   * @throws Exception
   */
  public static File ensureDir(File tgtDir) throws Exception {
    if (tgtDir.exists()) {
      if (tgtDir.isDirectory()) return tgtDir;
      else
        throw new Exception("Could not create directory "+tgtDir.getAbsolutePath()+", as a file already exists at that path.");
    } else {
      tgtDir.mkdirs();
      return tgtDir;
    }
  }

  public static void main(String[] args) {
    System.out.println(backupName(args[0]));
  }

  public static String getExtension(String fileName) {
    if(!fileName.contains("."))
      return null;
    int idx = fileName.lastIndexOf(".");
    return fileName.substring(idx+1);
  }

}
